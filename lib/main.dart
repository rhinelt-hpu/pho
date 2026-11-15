import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:img_syncer/desktop/home_page.dart';
import 'package:img_syncer/event_bus.dart';
import 'package:img_syncer/global.dart';
import 'package:img_syncer/logger/logger.dart';
import 'package:img_syncer/util.dart';
import 'package:provider/provider.dart';
import 'package:img_syncer/state_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'gallery_body.dart';
import 'sync_body.dart';
import 'settings_route.dart';
import 'package:adaptive_theme/adaptive_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/services.dart';
import 'package:img_syncer/l10n/app_localizations.dart';
import 'package:img_syncer/theme.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:img_syncer/design_tokens.dart';
import 'package:img_syncer/onboarding/onboarding_route.dart';
// iOS 后台同步 headless entrypoint，必须被 main 的 import 图可达，
// 否则 Debug Dart kernel 不会编译此库，BGProcessingTask 启动 headless
// engine 时 Dart_LookupLibrary 找不到它。
// ignore: unused_import
import 'background_sync_entrypoint.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (talker.settings.enabled) {
      talker.handle(
          details.exception, details.stack, details.summary.toString());
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (talker.settings.enabled) {
      talker.handle(error, stack);
    }
    return false;
  };
  startupLog('main entry');
  // 首帧之前不 await 任何东西：立刻 runApp，先渲染品牌启动页
  // （与原生 LaunchScreen 同视觉），初始化全部推到首帧之后。
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => settingModel),
        ChangeNotifierProvider(create: (context) => assetModel),
        ChangeNotifierProvider(create: (context) => stateModel),
      ],
      child: const MyApp(),
    ),
  );
  startupLog('runApp returned');
}

/// 启动页背景色：与 ios/Runner/Base.lproj/LaunchScreen.storyboard
/// 以及 android 的 launch_background.xml 保持一致，原生 → Dart 无跳变。
const Color splashBackgroundColor = Color(0xFF0A0A3D);

/// 启动页图标边长（pt），与原生 LaunchScreen 的 LaunchLogo 约束一致。
const double splashLogoSize = 112;

/// 深色启动页上的状态栏/导航栏样式（白字）
const SystemUiOverlayStyle splashOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light, // Android
  statusBarBrightness: Brightness.dark, // iOS
  systemNavigationBarColor: splashBackgroundColor,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// 应用主界面的状态栏/导航栏样式
const SystemUiOverlayStyle appOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent, // 设置状态栏颜色为透明
  systemNavigationBarColor: Colors.transparent, // 设置导航栏颜色为透明
  systemNavigationBarDividerColor: Colors.transparent, // 设置导航栏分隔线颜色为透明
);

/// 品牌启动页：纯色背景 + 居中图标 + 进度指示，无文字（避免 l10n/字体加载）。
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: splashOverlayStyle,
      child: ColoredBox(
        color: splashBackgroundColor,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image(
                // 1024×1024 原图按 3x 尺寸解码，降低首帧解码开销
                image: ResizeImage(
                  AssetImage('assets/icon/pho_icon.png'),
                  width: 336,
                  height: 336,
                ),
                width: splashLogoSize,
                height: splashLogoSize,
              ),
              SizedBox(height: 28),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF02FED1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 首帧（品牌启动页）之后才跑后台初始化，完成后切到 [_AppEntryPoint]。
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _ready = false;
  bool _needsOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startupLog('firstFrame');
      unawaited(_bootstrap());
    });
  }

  Future<void> _bootstrap() async {
    var needsOnboarding = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasOnboarded = prefs.getBool('has_onboarded') ?? false;
      // 容错：如果用户已经配置了网络存储或相册，说明已经在使用，绝不重复弹出新手引导
      final hasConfiguredStorage =
          (prefs.getString('webdav_url')?.isNotEmpty ?? false) ||
              (prefs.getString('smb_host')?.isNotEmpty ?? false) ||
              (prefs.getString('nfs_host')?.isNotEmpty ?? false);
      if (hasConfiguredStorage && !hasOnboarded) {
        unawaited(prefs.setBool('has_onboarded', true));
      }
      needsOnboarding = !(hasOnboarded || hasConfiguredStorage);
      startupLog('prefs loaded');
      // Go 内核 / 缩略图缓存 / 设置加载等，全部在首帧之后。
      // 超时只是兜底：Go 内核卡死时也不把用户锁在启动页（启动流程会自己继续跑）
      await Global.ensureStarted().timeout(const Duration(seconds: 15),
          onTimeout: () =>
              startupLog('global init timeout after 15s, enter app anyway'));
    } catch (e) {
      // 初始化失败也要进主界面，不能把用户卡在启动页
      startupLog('bootstrap failed: $e');
    }
    if (!mounted) return;
    // 启动页是深色底（白字状态栏），进主界面前恢复应用自己的浅色状态栏样式
    SystemChrome.setSystemUIOverlayStyle(appOverlayStyle);
    setState(() {
      _needsOnboarding = needsOnboarding;
      _ready = true;
    });
    startupLog('app entry shown');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const _SplashScreen();
    }
    return _AppEntryPoint(initialNeedsOnboarding: _needsOnboarding);
  }
}

class _AppEntryPoint extends StatefulWidget {
  final bool initialNeedsOnboarding;
  const _AppEntryPoint({required this.initialNeedsOnboarding});
  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  late bool _needsOnboarding;

  @override
  void initState() {
    super.initState();
    _needsOnboarding = widget.initialNeedsOnboarding;
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_onboarded', true);
    if (!mounted) return;
    setState(() {
      _needsOnboarding = false;
    });
    // 引导页可能遮住了系统权限弹窗，导致首次照片加载失败。
    // 退出引导页后重新触发加载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      eventBus.fire(LocalRefreshEvent(refreshUnSync: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    initI18n(context);
    if (_needsOnboarding) {
      return OnboardingRoute(onComplete: _finishOnboarding);
    }
    return const MyHomePage(title: 'PHO');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  static const String _title = 'PHO';
  // This widget is the root of your application.

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(appOverlayStyle);
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        late ColorScheme lightColorScheme;
        late ColorScheme darkColorScheme;
        if (lightDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
        } else {
          print("lightDynamic is null");
          lightColorScheme = ColorScheme.fromSeed(
            seedColor: seedColor ?? seedThemeColors[0],
            brightness: Brightness.light,
          );
        }
        if (darkDynamic != null) {
          darkColorScheme = darkDynamic.harmonized();
        } else {
          print("darkDynamic is null");
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: seedColor ?? seedThemeColors[0],
            brightness: Brightness.dark,
          );
        }

        var lightTheme = buildThemeData(
          colorScheme: lightColorScheme,
          brightness: Brightness.light,
        );
        var darkTheme = buildThemeData(
          colorScheme: darkColorScheme,
          brightness: Brightness.dark,
        );
        return AdaptiveTheme(
            light: lightTheme,
            dark: darkTheme,
            initial: AdaptiveThemeMode.light,
            // 始终浅色：以前是在每次启动时 prefs.remove('adaptive_theme') 写盘一次，
            // 而 adaptive_theme 3.x 实际读的 key 是 'adaptive_theme_preferences'，
            // overrideMode 才是真正生效且只在必要时落盘的做法。
            overrideMode: AdaptiveThemeMode.light,
            builder: (theme, darkTheme) {
              return MaterialApp(
                title: _title,
                debugShowCheckedModeBanner: false,
                home: const _Bootstrap(),
                theme: theme,
                darkTheme: darkTheme,
                themeMode: ThemeMode.light,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              );
            });
      },
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    SnackBarManager.init(context);
    SharedPreferences.getInstance().then((prefs) async {
      final seedColorValue = prefs.getInt("seed_color");
      if (seedColorValue != null) {
        seedColor = Color(seedColorValue);
        AdaptiveTheme.of(context).setTheme(
          light: buildThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor!,
              brightness: Brightness.light,
            ),
            brightness: Brightness.light,
          ),
        );
      }
    });
    if (!isDesktop()) {
      Connectivity().checkConnectivity().then((results) {
        stateModel.setOnline(!results.contains(ConnectivityResult.none));
      });
      Connectivity().onConnectivityChanged.listen((results) {
        stateModel.setOnline(!results.contains(ConnectivityResult.none));
      });
    }
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      stateModel.needStopSync = true;
    } else if (state == AppLifecycleState.resumed) {
      // 息屏/切后台后回到前台：连接可能已被系统冻结失效。
      // 重置中断标志，强制探测 Go server（绕过 60s 去抖），并触发 cloud 刷新。
      stateModel.needStopSync = false;
      lastAliveTime = null;
      checkServer().then((_) {
        if (settingModel.isRemoteStorageSetted) {
          eventBus.fire(RemoteRefreshEvent(refreshUnSync: false));
        }
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    initI18n(context);
    initRequestPermission(context);
    PreferredSizeWidget? appBar;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return !isDesktop()
        ? Consumer<StateModel>(
            builder: (context, model, child) => Scaffold(
              appBar: appBar,
              backgroundColor: colorScheme.surface,
              body: Column(
                children: [
                  if (!model.isOnline)
                    Container(
                      width: double.infinity,
                      color: colorScheme.errorContainer,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Text(
                        l10n.offline,
                        textAlign: TextAlign.center,
                        style: textTheme.labelSmall
                            ?.copyWith(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                        GalleryBody(
                          useLocal: true,
                        ),
                        GalleryBody(useLocal: false),
                        Consumer<SettingModel>(
                          builder: (context, model, child) {
                            return SyncBody(
                              localFolder: model.localFolder,
                            );
                          },
                        ),
                        const SettingsRoute(),
                      ],
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: model.isSelectionMode
                  ? null
                  : NavigationBar(
                      onDestinationSelected: _onItemTapped,
                      selectedIndex: _selectedIndex,
                      destinations: <Widget>[
                        NavigationDestination(
                          icon: const Icon(Icons.phone_android_outlined),
                          selectedIcon: const Icon(Icons.phone_android),
                          label: l10n.local,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.cloud_outlined),
                          selectedIcon: const Icon(Icons.cloud),
                          label: l10n.cloud,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.cloud_sync_outlined),
                          selectedIcon: const Icon(Icons.cloud_sync),
                          label: l10n.sync,
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.settings_outlined),
                          selectedIcon: const Icon(Icons.settings),
                          label: l10n.settings,
                        ),
                      ],
                    ),
            ),
          )
        : const DesktopHomePage();
  }
}

ThemeData buildThemeData({
  required ColorScheme colorScheme,
  required Brightness brightness,
}) {
  return ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    textTheme: textTheme,
    navigationBarTheme: brightness == Brightness.light
        ? buildNavigationBarThemeLight(colorScheme)
        : buildNavigationBarThemeDark(colorScheme),
    iconTheme: brightness == Brightness.light ? iconThemeLight : iconThemeDark,
    floatingActionButtonTheme: brightness == Brightness.light
        ? floatingActionButtonThemeLight
        : const FloatingActionButtonThemeData(),
    appBarTheme: buildAppBarTheme(colorScheme),
    cardTheme: buildCardTheme(colorScheme),
    listTileTheme: buildListTileTheme(colorScheme),
    chipTheme: buildChipTheme(colorScheme),
    dialogTheme: buildDialogTheme(colorScheme),
    snackBarTheme: buildSnackBarTheme(colorScheme),
    dividerTheme: buildDividerTheme(colorScheme),
    switchTheme: buildSwitchTheme(colorScheme),
    inputDecorationTheme: buildInputDecorationTheme(colorScheme),
    navigationRailTheme: buildNavigationRailTheme(colorScheme),
    bottomSheetTheme: buildBottomSheetTheme(colorScheme),
    progressIndicatorTheme: buildProgressIndicatorTheme(colorScheme),
    sliderTheme: buildSliderTheme(colorScheme),
    filledButtonTheme: buildFilledButtonTheme(colorScheme),
    textButtonTheme: buildTextButtonTheme(colorScheme),
    outlinedButtonTheme: buildOutlinedButtonTheme(colorScheme),
    segmentedButtonTheme: buildSegmentedButtonTheme(colorScheme),
    dropdownMenuTheme: buildDropdownMenuTheme(colorScheme),
    popupMenuTheme: buildPopupMenuTheme(colorScheme),
    tooltipTheme: buildTooltipTheme(colorScheme),
    badgeTheme: buildBadgeTheme(colorScheme),
  );
}
