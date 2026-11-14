import 'dart:ffi';
import 'dart:io';

// Win32 / COM constants
const int _coinitApartmentThreaded = 0x2;
const int _coinitMultiThreaded = 0x0;
const int _rpcChangedMode = -2147417850; // 0x80010106 RPC_E_CHANGED_MODE
const int _clsctxInprocServer = 0x1;

// Native function typedefs for ole32.dll
typedef _CoInitializeExNative = Int32 Function(
  Pointer<Void> pvReserved,
  Uint32 dwCoInit,
);
typedef _CoInitializeExDart = int Function(
  Pointer<Void> pvReserved,
  int dwCoInit,
);

typedef _CoCreateInstanceNative = Int32 Function(
  Pointer<Uint8> rclsid,
  Pointer<Void> pUnkOuter,
  Uint32 dwClsContext,
  Pointer<Uint8> riid,
  Pointer<Pointer<Void>> ppv,
);
typedef _CoCreateInstanceDart = int Function(
  Pointer<Uint8> rclsid,
  Pointer<Void> pUnkOuter,
  int dwClsContext,
  Pointer<Uint8> riid,
  Pointer<Pointer<Void>> ppv,
);

typedef _CoTaskMemAllocNative = Pointer<Void> Function(IntPtr cb);
typedef _CoTaskMemAllocDart = Pointer<Void> Function(int cb);

typedef _CoTaskMemFreeNative = Void Function(Pointer<Void> pv);
typedef _CoTaskMemFreeDart = void Function(Pointer<Void> pv);

// COM IUnknown::Release (vtable[2])
typedef _ReleaseNative = Uint32 Function(Pointer<Void> self);
typedef _ReleaseDart = int Function(Pointer<Void> self);

// ISpellCheckerFactory::IsSupported (vtable[4])
typedef _IsSupportedNative = Int32 Function(
  Pointer<Void> self,
  Pointer<Uint16> languageTag,
  Pointer<Int32> value,
);
typedef _IsSupportedDart = int Function(
  Pointer<Void> self,
  Pointer<Uint16> languageTag,
  Pointer<Int32> value,
);

// ISpellCheckerFactory::CreateSpellChecker (vtable[5])
typedef _CreateSpellCheckerNative = Int32 Function(
  Pointer<Void> self,
  Pointer<Uint16> languageTag,
  Pointer<Pointer<Void>> value,
);
typedef _CreateSpellCheckerDart = int Function(
  Pointer<Void> self,
  Pointer<Uint16> languageTag,
  Pointer<Pointer<Void>> value,
);

// ISpellChecker::Check (vtable[4])
typedef _CheckNative = Int32 Function(
  Pointer<Void> self,
  Pointer<Uint16> text,
  Pointer<Pointer<Void>> value,
);
typedef _CheckDart = int Function(
  Pointer<Void> self,
  Pointer<Uint16> text,
  Pointer<Pointer<Void>> value,
);

// ISpellChecker::Suggest (vtable[5])
typedef _SuggestNative = Int32 Function(
  Pointer<Void> self,
  Pointer<Uint16> word,
  Pointer<Pointer<Void>> value,
);
typedef _SuggestDart = int Function(
  Pointer<Void> self,
  Pointer<Uint16> word,
  Pointer<Pointer<Void>> value,
);

// IEnumSpellingError::Next (vtable[3])
typedef _EnumSpellingErrorNextNative = Int32 Function(
  Pointer<Void> self,
  Pointer<Pointer<Void>> value,
);
typedef _EnumSpellingErrorNextDart = int Function(
  Pointer<Void> self,
  Pointer<Pointer<Void>> value,
);

// IEnumString::Next (vtable[3])
typedef _EnumStringNextNative = Int32 Function(
  Pointer<Void> self,
  Uint32 celt,
  Pointer<Pointer<Uint16>> rgelt,
  Pointer<Uint32> pceltFetched,
);
typedef _EnumStringNextDart = int Function(
  Pointer<Void> self,
  int celt,
  Pointer<Pointer<Uint16>> rgelt,
  Pointer<Uint32> pceltFetched,
);

/// Thin FFI wrapper around Windows' built-in `ISpellChecker` COM API
/// (`MsSpellCheckFacility`).
class WindowsSpellChecker {
  static const List<int> _clsidSpellCheckerFactory = [
    0x53,
    0x66,
    0xB3,
    0x7A,
    0x96,
    0x17,
    0x4B,
    0x48,
    0xBD,
    0xFA,
    0xE7,
    0x4F,
    0x1D,
    0xB7,
    0xC1,
    0xDC,
  ];
  static const List<int> _iidISpellCheckerFactory = [
    0x9D,
    0x8A,
    0x01,
    0x8E,
    0x15,
    0x24,
    0x77,
    0x46,
    0xBF,
    0x08,
    0x79,
    0x4E,
    0xA6,
    0x1F,
    0x94,
    0xBB,
  ];

  late final DynamicLibrary _ole32;
  late final _CoInitializeExDart _coInitializeEx;
  late final _CoCreateInstanceDart _coCreateInstance;
  late final _CoTaskMemAllocDart _coTaskMemAlloc;
  late final _CoTaskMemFreeDart _coTaskMemFree;

  Pointer<Void> _factory = nullptr;
  Pointer<Void> _checker = nullptr;
  String _activeLanguage = 'en-GB';
  bool _isDisposed = false;

  bool get isAvailable => _checker != nullptr && !_isDisposed;
  String get activeLanguage => _activeLanguage;

  WindowsSpellChecker._();

  /// Attempts to initialise the Windows COM spellchecker for [languageTag]
  /// (falling back to `en-US` if [languageTag] is not installed).
  /// Returns `null` on non-Windows platforms or if COM initialisation fails.
  static WindowsSpellChecker? create({String languageTag = 'en-GB'}) {
    if (!Platform.isWindows) return null;
    try {
      final instance = WindowsSpellChecker._();
      if (instance._init(languageTag)) {
        return instance;
      }
      instance.dispose();
    } catch (_) {
      // Fall back gracefully if COM spellchecker is unavailable.
    }
    return null;
  }

  bool _init(String languageTag) {
    _ole32 = DynamicLibrary.open('ole32.dll');
    _coInitializeEx = _ole32
        .lookupFunction<_CoInitializeExNative, _CoInitializeExDart>(
          'CoInitializeEx',
        );
    _coCreateInstance = _ole32
        .lookupFunction<_CoCreateInstanceNative, _CoCreateInstanceDart>(
          'CoCreateInstance',
        );
    _coTaskMemAlloc = _ole32
        .lookupFunction<_CoTaskMemAllocNative, _CoTaskMemAllocDart>(
          'CoTaskMemAlloc',
        );
    _coTaskMemFree = _ole32
        .lookupFunction<_CoTaskMemFreeNative, _CoTaskMemFreeDart>(
          'CoTaskMemFree',
        );

    int hr = _coInitializeEx(nullptr, _coinitApartmentThreaded);
    if (hr == _rpcChangedMode) {
      hr = _coInitializeEx(nullptr, _coinitMultiThreaded);
    }
    // S_OK (0) or S_FALSE (1) or RPC_E_CHANGED_MODE means COM is ready on this thread.
    if (hr < 0 && hr != _rpcChangedMode) {
      return false;
    }

    final clsidPtr = _allocBytes(_clsidSpellCheckerFactory);
    final iidPtr = _allocBytes(_iidISpellCheckerFactory);
    final factoryOut = _coTaskMemAlloc(sizeOf<Pointer<Void>>())
        .cast<Pointer<Void>>();
    factoryOut.value = nullptr;

    try {
      final createHr = _coCreateInstance(
        clsidPtr,
        nullptr,
        _clsctxInprocServer,
        iidPtr,
        factoryOut,
      );
      if (createHr < 0 || factoryOut.value == nullptr) {
        return false;
      }
      _factory = factoryOut.value;
    } finally {
      _coTaskMemFree(clsidPtr.cast());
      _coTaskMemFree(iidPtr.cast());
      _coTaskMemFree(factoryOut.cast());
    }

    return setLanguage(languageTag);
  }

  /// Switches the active spellchecker language, falling back to `en-US` if
  /// [languageTag] is not supported on this machine.
  bool setLanguage(String languageTag) {
    if (_factory == nullptr || _isDisposed) return false;

    String? target = _isLanguageSupported(languageTag) ? languageTag : null;
    target ??= (languageTag != 'en-GB' && _isLanguageSupported('en-GB'))
        ? 'en-GB'
        : null;
    target ??= (languageTag != 'en-US' && _isLanguageSupported('en-US'))
        ? 'en-US'
        : null;
    if (target == null) return false;

    final langPtr = _toUtf16(target);
    final checkerOut = _coTaskMemAlloc(sizeOf<Pointer<Void>>())
        .cast<Pointer<Void>>();
    checkerOut.value = nullptr;

    try {
      final createSpellChecker = _vtablePtr(_factory, 5)
          .cast<NativeFunction<_CreateSpellCheckerNative>>()
          .asFunction<_CreateSpellCheckerDart>();
      final hr = createSpellChecker(_factory, langPtr, checkerOut);
      if (hr < 0 || checkerOut.value == nullptr) {
        return false;
      }
      if (_checker != nullptr) {
        _release(_checker);
      }
      _checker = checkerOut.value;
      _activeLanguage = target;
      return true;
    } finally {
      _coTaskMemFree(langPtr.cast());
      _coTaskMemFree(checkerOut.cast());
    }
  }

  bool _isLanguageSupported(String languageTag) {
    final langPtr = _toUtf16(languageTag);
    final resultPtr = _coTaskMemAlloc(sizeOf<Int32>()).cast<Int32>();
    resultPtr.value = 0;
    try {
      final isSupported = _vtablePtr(_factory, 4)
          .cast<NativeFunction<_IsSupportedNative>>()
          .asFunction<_IsSupportedDart>();
      final hr = isSupported(_factory, langPtr, resultPtr);
      return hr >= 0 && resultPtr.value != 0;
    } finally {
      _coTaskMemFree(langPtr.cast());
      _coTaskMemFree(resultPtr.cast());
    }
  }

  /// Returns `true` if [word] is spelled correctly according to Windows.
  bool checkWord(String word) {
    if (!isAvailable || word.isEmpty) return true;

    final wordPtr = _toUtf16(word);
    final enumOut = _coTaskMemAlloc(sizeOf<Pointer<Void>>())
        .cast<Pointer<Void>>();
    enumOut.value = nullptr;

    try {
      final checkFn = _vtablePtr(
        _checker,
        4,
      ).cast<NativeFunction<_CheckNative>>().asFunction<_CheckDart>();
      final hr = checkFn(_checker, wordPtr, enumOut);
      if (hr < 0 || enumOut.value == nullptr) {
        return true;
      }
      final enumPtr = enumOut.value;
      final errOut = _coTaskMemAlloc(sizeOf<Pointer<Void>>())
          .cast<Pointer<Void>>();
      errOut.value = nullptr;

      try {
        final nextFn = _vtablePtr(enumPtr, 3)
            .cast<NativeFunction<_EnumSpellingErrorNextNative>>()
            .asFunction<_EnumSpellingErrorNextDart>();
        final nextHr = nextFn(enumPtr, errOut);
        // S_OK (0) means an ISpellingError was returned; S_FALSE (1) means no errors.
        if (nextHr == 0 && errOut.value != nullptr) {
          _release(errOut.value);
          return false;
        }
        return true;
      } finally {
        _release(enumPtr);
        _coTaskMemFree(errOut.cast());
      }
    } finally {
      _coTaskMemFree(wordPtr.cast());
      _coTaskMemFree(enumOut.cast());
    }
  }

  /// Returns up to [maxSuggestions] spelling suggestions for [word].
  List<String> suggest(String word, {int maxSuggestions = 5}) {
    if (!isAvailable || word.isEmpty) return const [];

    final wordPtr = _toUtf16(word);
    final enumOut = _coTaskMemAlloc(sizeOf<Pointer<Void>>())
        .cast<Pointer<Void>>();
    enumOut.value = nullptr;

    try {
      final suggestFn = _vtablePtr(
        _checker,
        5,
      ).cast<NativeFunction<_SuggestNative>>().asFunction<_SuggestDart>();
      final hr = suggestFn(_checker, wordPtr, enumOut);
      if (hr < 0 || enumOut.value == nullptr) {
        return const [];
      }

      final enumPtr = enumOut.value;
      final rgelt = _coTaskMemAlloc(sizeOf<Pointer<Uint16>>())
          .cast<Pointer<Uint16>>();
      final fetched = _coTaskMemAlloc(sizeOf<Uint32>()).cast<Uint32>();
      final results = <String>[];

      try {
        final nextFn = _vtablePtr(enumPtr, 3)
            .cast<NativeFunction<_EnumStringNextNative>>()
            .asFunction<_EnumStringNextDart>();
        while (results.length < maxSuggestions) {
          rgelt.value = nullptr;
          fetched.value = 0;
          final nextHr = nextFn(enumPtr, 1, rgelt, fetched);
          if (nextHr != 0 || fetched.value == 0 || rgelt.value == nullptr) {
            break;
          }
          final suggestion = _fromUtf16(rgelt.value);
          _coTaskMemFree(rgelt.value.cast());
          if (suggestion.isNotEmpty) {
            results.add(suggestion);
          }
        }
      } finally {
        _release(enumPtr);
        _coTaskMemFree(rgelt.cast());
        _coTaskMemFree(fetched.cast());
      }

      return results;
    } finally {
      _coTaskMemFree(wordPtr.cast());
      _coTaskMemFree(enumOut.cast());
    }
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    if (_checker != nullptr) {
      _release(_checker);
      _checker = nullptr;
    }
    if (_factory != nullptr) {
      _release(_factory);
      _factory = nullptr;
    }
  }

  void _release(Pointer<Void> comPtr) {
    final releaseFn = _vtablePtr(
      comPtr,
      2,
    ).cast<NativeFunction<_ReleaseNative>>().asFunction<_ReleaseDart>();
    releaseFn(comPtr);
  }

  Pointer<Void> _vtablePtr(Pointer<Void> comPtr, int index) {
    final vtable = comPtr.cast<Pointer<Pointer<Void>>>().value;
    return vtable[index];
  }

  Pointer<Uint8> _allocBytes(List<int> bytes) {
    final ptr = _coTaskMemAlloc(bytes.length).cast<Uint8>();
    for (int i = 0; i < bytes.length; i++) {
      ptr[i] = bytes[i];
    }
    return ptr;
  }

  Pointer<Uint16> _toUtf16(String text) {
    final units = text.codeUnits;
    final ptr = _coTaskMemAlloc((units.length + 1) * 2).cast<Uint16>();
    for (int i = 0; i < units.length; i++) {
      ptr[i] = units[i];
    }
    ptr[units.length] = 0;
    return ptr;
  }

  String _fromUtf16(Pointer<Uint16> ptr) {
    final units = <int>[];
    int i = 0;
    while (true) {
      final code = ptr[i];
      if (code == 0) break;
      units.add(code);
      i++;
    }
    return String.fromCharCodes(units);
  }
}
