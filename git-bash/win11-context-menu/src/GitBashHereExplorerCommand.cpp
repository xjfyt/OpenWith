#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <shellapi.h>

#include <filesystem>
#include <new>
#include <string>

// {EE3EDDBD-613B-4D0C-B65F-50B21BB8F678}
static const CLSID CLSID_GitBashHereExplorerCommand =
{ 0xee3eddbd, 0x613b, 0x4d0c, { 0xb6, 0x5f, 0x50, 0xb2, 0x1b, 0xb8, 0xf6, 0x78 } };

static volatile LONG g_dllRefCount = 0;
static const wchar_t kSettingsKey[] = L"Software\\Classes\\GitBashHereContextMenu";
static const wchar_t kFallbackTitle[] = L"Git Bash Here";

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

static bool ReadRegistryString(HKEY root, const wchar_t* valueName, std::wstring& value) {
	HKEY key = nullptr;
	LONG result = RegOpenKeyExW(root, kSettingsKey, 0, KEY_READ | KEY_WOW64_64KEY, &key);
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

static std::wstring ReadSetting(const wchar_t* valueName, const wchar_t* fallback = L"") {
	std::wstring value;
	if (ReadRegistryString(HKEY_CURRENT_USER, valueName, value)) {
		return value;
	}
	if (ReadRegistryString(HKEY_LOCAL_MACHINE, valueName, value)) {
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
	ExplorerCommandHandler() : refCount_(1) {
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
		return DuplicateString(ReadSetting(L"Title", kFallbackTitle), name);
	}

	IFACEMETHODIMP GetIcon(IShellItemArray*, PWSTR* icon) override {
		return DuplicateString(ReadSetting(L"ExePath"), icon);
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

		const std::wstring exePath = ReadSetting(L"ExePath");
		*cmdState = (!exePath.empty() && std::filesystem::exists(exePath)) ? ECS_ENABLED : ECS_HIDDEN;
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
		const std::wstring exePath = ReadSetting(L"ExePath");
		if (exePath.empty() || !std::filesystem::exists(exePath)) {
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

			std::wstring directory = DirectoryForPath(path);
			CoTaskMemFree(path);
			if (directory.empty()) {
				continue;
			}

			std::wstring args = L"--cd=" + directory;
			HINSTANCE result = ShellExecuteW(nullptr, L"open", exePath.c_str(), QuoteForCommandLineArg(args).c_str(), directory.c_str(), SW_SHOWNORMAL);
			if (reinterpret_cast<INT_PTR>(result) <= HINSTANCE_ERROR) {
				return HRESULT_FROM_WIN32(GetLastError());
			}
		}

		return S_OK;
	}

private:
	volatile LONG refCount_;
};

class ExplorerCommandClassFactory final : public IClassFactory {
public:
	ExplorerCommandClassFactory() : refCount_(1) {
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

		ExplorerCommandHandler* handler = new (std::nothrow) ExplorerCommandHandler();
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
};

STDAPI DllGetClassObject(REFCLSID clsid, REFIID riid, void** object) {
	if (!IsEqualCLSID(clsid, CLSID_GitBashHereExplorerCommand)) {
		return CLASS_E_CLASSNOTAVAILABLE;
	}

	ExplorerCommandClassFactory* factory = new (std::nothrow) ExplorerCommandClassFactory();
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
