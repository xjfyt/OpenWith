#include <windows.h>
#include <shobjidl.h>
#include <shellapi.h>

#include <filesystem>
#include <new>
#include <string>
#include <utility>

static volatile LONG g_dllRefCount = 0;
static const wchar_t kRootKey[] = L"Software\\Classes\\OpenWithContextMenus";
static const wchar_t kFallbackTitle[] = L"Open With";

static std::wstring QuoteForCommandLineArg(const std::wstring& arg) {
	std::wstring out;
	out.push_back(L'"');

	for (size_t i = 0; i < arg.size(); ++i) {
		if (arg[i] == L'\\') {
			size_t end = i;
			while (end < arg.size() && arg[end] == L'\\') {
				++end;
			}

			const size_t backslashCount = end - i;
			if (end == arg.size()) {
				for (size_t j = 0; j < backslashCount * 2; ++j) {
					out.push_back(L'\\');
				}
			} else if (arg[end] == L'"') {
				for (size_t j = 0; j < backslashCount * 2 + 1; ++j) {
					out.push_back(L'\\');
				}
				out.push_back(L'"');
				i = end;
			} else {
				for (size_t j = 0; j < backslashCount; ++j) {
					out.push_back(L'\\');
				}
				i = end - 1;
			}
		} else if (arg[i] == L'"') {
			out.push_back(L'\\');
			out.push_back(L'"');
		} else {
			out.push_back(arg[i]);
		}
	}

	out.push_back(L'"');
	return out;
}

static bool ReadRegistryString(HKEY root, const std::wstring& keyPath, const wchar_t* valueName, std::wstring& value) {
	HKEY key = nullptr;
	LONG result = RegOpenKeyExW(root, keyPath.c_str(), 0, KEY_READ | KEY_WOW64_64KEY, &key);
	if (result != ERROR_SUCCESS) {
		return false;
	}

	DWORD type = 0;
	DWORD size = 0;
	result = RegQueryValueExW(key, valueName, nullptr, &type, nullptr, &size);
	if (result != ERROR_SUCCESS || (type != REG_SZ && type != REG_EXPAND_SZ) || size == 0) {
		RegCloseKey(key);
		return false;
	}

	std::wstring buffer(size / sizeof(wchar_t), L'\0');
	result = RegQueryValueExW(key, valueName, nullptr, &type, reinterpret_cast<LPBYTE>(buffer.data()), &size);
	RegCloseKey(key);
	if (result != ERROR_SUCCESS) {
		return false;
	}

	if (!buffer.empty() && buffer.back() == L'\0') {
		buffer.pop_back();
	}

	if (type == REG_EXPAND_SZ) {
		DWORD expandedSize = ExpandEnvironmentStringsW(buffer.c_str(), nullptr, 0);
		if (expandedSize > 0) {
			std::wstring expanded(expandedSize, L'\0');
			DWORD written = ExpandEnvironmentStringsW(buffer.c_str(), expanded.data(), expandedSize);
			if (written > 0 && written <= expandedSize) {
				if (!expanded.empty() && expanded.back() == L'\0') {
					expanded.pop_back();
				}
				buffer = expanded;
			}
		}
	}

	value = buffer;
	return !value.empty();
}

static std::wstring ReadSetting(const std::wstring& settingsKey, const wchar_t* valueName, const wchar_t* fallback = L"") {
	std::wstring value;
	if (ReadRegistryString(HKEY_CURRENT_USER, settingsKey, valueName, value)) {
		return value;
	}
	if (ReadRegistryString(HKEY_LOCAL_MACHINE, settingsKey, valueName, value)) {
		return value;
	}
	return fallback;
}

static HRESULT DuplicateString(const std::wstring& value, PWSTR* output) {
	if (!output) {
		return E_POINTER;
	}
	*output = nullptr;

	const size_t bytes = (value.size() + 1) * sizeof(wchar_t);
	PWSTR copy = static_cast<PWSTR>(CoTaskMemAlloc(bytes));
	if (!copy) {
		return E_OUTOFMEMORY;
	}
	memcpy(copy, value.c_str(), bytes);
	*output = copy;
	return S_OK;
}

static std::wstring GuidToString(REFCLSID clsid) {
	wchar_t buffer[39] = {};
	if (StringFromGUID2(clsid, buffer, ARRAYSIZE(buffer)) == 0) {
		return L"";
	}
	return buffer;
}

static std::wstring ToolIdForClass(REFCLSID clsid) {
	const std::wstring guid = GuidToString(clsid);
	if (guid.empty()) {
		return L"";
	}

	const std::wstring classMapKey = std::wstring(kRootKey) + L"\\ClassMap\\" + guid;
	std::wstring toolId;
	if (ReadRegistryString(HKEY_CURRENT_USER, classMapKey, L"ToolId", toolId)) {
		return toolId;
	}
	if (ReadRegistryString(HKEY_LOCAL_MACHINE, classMapKey, L"ToolId", toolId)) {
		return toolId;
	}
	return L"";
}

static std::wstring SettingsKeyForTool(const std::wstring& toolId) {
	return std::wstring(kRootKey) + L"\\Tools\\" + toolId;
}

static bool ExecutableExists(const std::wstring& exePath) {
	if (exePath.empty()) {
		return false;
	}

	if (std::filesystem::exists(exePath)) {
		return true;
	}

	if (exePath.find(L'\\') != std::wstring::npos || exePath.find(L'/') != std::wstring::npos) {
		return false;
	}

	wchar_t resolved[MAX_PATH] = {};
	return SearchPathW(nullptr, exePath.c_str(), nullptr, ARRAYSIZE(resolved), resolved, nullptr) > 0;
}

static std::wstring DirectoryForPath(const wchar_t* rawPath) {
	if (!rawPath || !*rawPath) {
		return L"";
	}

	std::filesystem::path path(rawPath);
	DWORD attributes = GetFileAttributesW(rawPath);
	if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
		return path.wstring();
	}

	std::filesystem::path parent = path.parent_path();
	return parent.empty() ? path.wstring() : parent.wstring();
}

class ExplorerCommandHandler final : public IExplorerCommand {
public:
	explicit ExplorerCommandHandler(std::wstring toolId)
		: refCount_(1), toolId_(std::move(toolId)), settingsKey_(SettingsKeyForTool(toolId_)) {
		InterlockedIncrement(&g_dllRefCount);
	}

	~ExplorerCommandHandler() {
		InterlockedDecrement(&g_dllRefCount);
	}

	IFACEMETHODIMP QueryInterface(REFIID riid, void** object) override {
		if (!object) {
			return E_POINTER;
		}
		*object = nullptr;

		if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IExplorerCommand)) {
			*object = static_cast<IExplorerCommand*>(this);
			AddRef();
			return S_OK;
		}

		return E_NOINTERFACE;
	}

	IFACEMETHODIMP_(ULONG) AddRef() override {
		return static_cast<ULONG>(InterlockedIncrement(&refCount_));
	}

	IFACEMETHODIMP_(ULONG) Release() override {
		ULONG ref = static_cast<ULONG>(InterlockedDecrement(&refCount_));
		if (ref == 0) {
			delete this;
		}
		return ref;
	}

	IFACEMETHODIMP GetTitle(IShellItemArray*, PWSTR* name) override {
		return DuplicateString(ReadSetting(settingsKey_, L"Title", kFallbackTitle), name);
	}

	IFACEMETHODIMP GetIcon(IShellItemArray*, PWSTR* icon) override {
		std::wstring iconPath = ReadSetting(settingsKey_, L"IconPath");
		if (iconPath.empty()) {
			iconPath = ReadSetting(settingsKey_, L"ExePath");
		}
		return DuplicateString(iconPath, icon);
	}

	IFACEMETHODIMP GetToolTip(IShellItemArray*, PWSTR* infoTip) override {
		if (!infoTip) {
			return E_POINTER;
		}
		*infoTip = nullptr;
		return E_NOTIMPL;
	}

	IFACEMETHODIMP GetCanonicalName(GUID* guidCommandName) override {
		if (!guidCommandName) {
			return E_POINTER;
		}
		*guidCommandName = GUID_NULL;
		return S_OK;
	}

	IFACEMETHODIMP GetState(IShellItemArray*, BOOL, EXPCMDSTATE* cmdState) override {
		if (!cmdState) {
			return E_POINTER;
		}

		const std::wstring exePath = ReadSetting(settingsKey_, L"ExePath");
		*cmdState = ExecutableExists(exePath) ? ECS_ENABLED : ECS_HIDDEN;
		return S_OK;
	}

	IFACEMETHODIMP GetFlags(EXPCMDFLAGS* flags) override {
		if (!flags) {
			return E_POINTER;
		}
		*flags = ECF_DEFAULT;
		return S_OK;
	}

	IFACEMETHODIMP EnumSubCommands(IEnumExplorerCommand** enumCommands) override {
		if (!enumCommands) {
			return E_POINTER;
		}
		*enumCommands = nullptr;
		return E_NOTIMPL;
	}

	IFACEMETHODIMP Invoke(IShellItemArray* items, IBindCtx*) override {
		const std::wstring exePath = ReadSetting(settingsKey_, L"ExePath");
		if (!ExecutableExists(exePath)) {
			return HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND);
		}

		if (!items) {
			return S_OK;
		}

		DWORD count = 0;
		HRESULT hr = items->GetCount(&count);
		if (FAILED(hr)) {
			return hr;
		}

		for (DWORD i = 0; i < count; ++i) {
			IShellItem* item = nullptr;
			hr = items->GetItemAt(i, &item);
			if (FAILED(hr)) {
				continue;
			}

			PWSTR path = nullptr;
			hr = item->GetDisplayName(SIGDN_FILESYSPATH, &path);
			item->Release();
			if (FAILED(hr)) {
				continue;
			}

			const std::wstring selectedPath(path);
			const std::wstring directory = DirectoryForPath(path);
			CoTaskMemFree(path);

			std::wstring workingDirectory;
			const std::wstring args = BuildArguments(selectedPath, directory, workingDirectory);
			const wchar_t* parameters = args.empty() ? nullptr : args.c_str();
			const wchar_t* directoryPtr = workingDirectory.empty() ? nullptr : workingDirectory.c_str();

			HINSTANCE result = ShellExecuteW(nullptr, L"open", exePath.c_str(), parameters, directoryPtr, SW_SHOWNORMAL);
			if (reinterpret_cast<INT_PTR>(result) <= HINSTANCE_ERROR) {
				return HRESULT_FROM_WIN32(GetLastError());
			}
		}

		return S_OK;
	}

private:
	std::wstring BuildArguments(const std::wstring& selectedPath, const std::wstring& directory, std::wstring& workingDirectory) const {
		const std::wstring mode = ReadSetting(settingsKey_, L"LaunchMode", L"OpenPath");

		if (mode == L"GitBashHere") {
			workingDirectory = directory;
			return QuoteForCommandLineArg(L"--cd=" + directory);
		}

		if (mode == L"WindowsTerminalHere") {
			workingDirectory = directory;
			return L"-d " + QuoteForCommandLineArg(directory);
		}

		if (mode == L"WslHere") {
			workingDirectory = directory;
			const std::wstring distro = ReadSetting(settingsKey_, L"Distro");
			if (!distro.empty()) {
				return L"-d " + QuoteForCommandLineArg(distro) + L" --cd " + QuoteForCommandLineArg(directory);
			}
			return L"--cd " + QuoteForCommandLineArg(directory);
		}

		if (mode == L"OpenDirectory") {
			workingDirectory = directory;
			return QuoteForCommandLineArg(directory);
		}

		return QuoteForCommandLineArg(selectedPath);
	}

	volatile LONG refCount_;
	std::wstring toolId_;
	std::wstring settingsKey_;
};

class ExplorerCommandClassFactory final : public IClassFactory {
public:
	explicit ExplorerCommandClassFactory(std::wstring toolId)
		: refCount_(1), toolId_(std::move(toolId)) {
		InterlockedIncrement(&g_dllRefCount);
	}

	~ExplorerCommandClassFactory() {
		InterlockedDecrement(&g_dllRefCount);
	}

	IFACEMETHODIMP QueryInterface(REFIID riid, void** object) override {
		if (!object) {
			return E_POINTER;
		}
		*object = nullptr;

		if (IsEqualIID(riid, IID_IUnknown) || IsEqualIID(riid, IID_IClassFactory)) {
			*object = static_cast<IClassFactory*>(this);
			AddRef();
			return S_OK;
		}

		return E_NOINTERFACE;
	}

	IFACEMETHODIMP_(ULONG) AddRef() override {
		return static_cast<ULONG>(InterlockedIncrement(&refCount_));
	}

	IFACEMETHODIMP_(ULONG) Release() override {
		ULONG ref = static_cast<ULONG>(InterlockedDecrement(&refCount_));
		if (ref == 0) {
			delete this;
		}
		return ref;
	}

	IFACEMETHODIMP CreateInstance(IUnknown* outer, REFIID riid, void** object) override {
		if (outer) {
			return CLASS_E_NOAGGREGATION;
		}

		ExplorerCommandHandler* handler = new (std::nothrow) ExplorerCommandHandler(toolId_);
		if (!handler) {
			return E_OUTOFMEMORY;
		}

		HRESULT hr = handler->QueryInterface(riid, object);
		handler->Release();
		return hr;
	}

	IFACEMETHODIMP LockServer(BOOL lock) override {
		if (lock) {
			InterlockedIncrement(&g_dllRefCount);
		} else {
			InterlockedDecrement(&g_dllRefCount);
		}
		return S_OK;
	}

private:
	volatile LONG refCount_;
	std::wstring toolId_;
};

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** object) {
	const std::wstring toolId = ToolIdForClass(clsid);
	if (toolId.empty()) {
		return CLASS_E_CLASSNOTAVAILABLE;
	}

	ExplorerCommandClassFactory* factory = new (std::nothrow) ExplorerCommandClassFactory(toolId);
	if (!factory) {
		return E_OUTOFMEMORY;
	}

	HRESULT hr = factory->QueryInterface(riid, object);
	factory->Release();
	return hr;
}

STDAPI DllCanUnloadNow() {
	return g_dllRefCount == 0 ? S_OK : S_FALSE;
}
