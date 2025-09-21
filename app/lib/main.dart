import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/mqtt_service.dart';
import 'services/storage_service.dart';
import 'services/voice_command_service.dart';
import 'services/tts_service.dart';
import 'services/automation_service.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/automation_screen.dart';
import 'utils/theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ปิด DebugService logs ที่ไม่ต้องการ
  if (kDebugMode) {
    // ปิด logs ที่ซ้ำๆ จาก Flutter framework
    debugPrint = (String? message, {int? wrapWidth}) {
      // กรองเฉพาะ logs ที่สำคัญ
      if (message != null && 
          !message.contains('DebugService: Error serving requests') &&
          !message.contains('Cannot send Null') &&
          !message.contains('Error serving requests') &&
          !message.contains('DebugService:')) {
        print(message);
      }
    };
  }
  
  try {
    // Initialize storage service
    final storageService = StorageService.instance;
    final initialized = await storageService.initialize();
    
    if (!initialized) {
      print('Warning: Storage service failed to initialize');
    }
    
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
    
    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    print('Initialization error: $e');
  }
  
  runApp(const SmartHomeApp());
}

class SmartHomeApp extends StatelessWidget {
  const SmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ApiService(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => MqttService(),
          lazy: false,
        ),
        ChangeNotifierProvider.value(
          value: StorageService.instance,
        ),
                 ChangeNotifierProvider(
           create: (_) => VoiceCommandService(),
           lazy: false,
         ),
         ChangeNotifierProvider<TtsService>(
           create: (_) => TtsService.instance,
           lazy: false,
         ),
         ChangeNotifierProvider(
           create: (_) => AutomationService(),
           lazy: false,
         ),
      ],
      child: Consumer<StorageService>(
        builder: (context, storage, child) {
          String appTheme = 'system';
          try {
            appTheme = storage.getAppTheme();
          } catch (e) {
            print('Storage theme error: $e');
          }
          
          final themeMode = _getThemeMode(appTheme);
          
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            home: const SplashScreen(),
            routes: {
              '/splash': (context) => SplashScreen(),
              '/main': (context) => MainNavigationScreen(),
              '/dashboard': (context) => HomeScreen(),
              '/chat': (context) => LogScreen(),
              '/settings': (context) => SettingsScreen(),
              '/automation': (context) => AutomationScreen(),
            },
            onGenerateRoute: (settings) {
              // Handle dynamic routes if needed
              switch (settings.name) {
                default:
                  return MaterialPageRoute(
                    builder: (context) => const SplashScreen(),
                  );
              }
            },
          );
        },
      ),
    );
  }

  ThemeMode _getThemeMode(String theme) {
    switch (theme) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  late PageController _pageController;
  bool _isConnecting = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    LogScreen(),
    AutomationScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.resumed:
        _reconnectServices();
        break;
      case AppLifecycleState.paused:
        _pauseServices();
        break;
      case AppLifecycleState.detached:
        _disconnectServices();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeServices() async {
    setState(() => _isConnecting = true);
    
    try {
      // Initialize MQTT connection
      final mqttService = Provider.of<MqttService>(context, listen: false);
      await mqttService.connect();
      
      // Test API connection
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.testConnection();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเชื่อมต่อบางบริการได้: $e'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _reconnectServices() async {
    try {
      final mqttService = Provider.of<MqttService>(context, listen: false);
      if (!mqttService.isConnected) {
        await mqttService.connect();
      }
    } catch (e) {
      // Silent fail for reconnection
    }
  }

  void _pauseServices() {
    // Optional: implement service pausing logic
  }

  void _disconnectServices() {
    try {
      final mqttService = Provider.of<MqttService>(context, listen: false);
      mqttService.disconnect();
    } catch (e) {
      // Silent fail for disconnection
    }
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      
      // Haptic feedback
      HapticFeedback.lightImpact();
    }
  }

  void _onPageChanged(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            children: _screens,
          ),
          
          // Connection overlay
          if (_isConnecting) ...[
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'กำลังเชื่อมต่อบริการ...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              activeIcon: Icon(Icons.assignment),
              label: 'Log',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy),
              activeIcon: Icon(Icons.smart_toy),
              label: 'ออโตเมชั่น',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              activeIcon: Icon(Icons.settings),
              label: 'ตั้งค่า',
            ),
          ],
        ),
      ),
      // ลบ persistentFooterButtons เพื่อไม่ให้มีเส้นเหลืองๆ
    );
  }
}

// Splash Screen (optional, can be used for app initialization)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    _animationController.forward();
    
    // Navigate to main screen after animation
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MainNavigationScreen(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.home,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      Text(
                        AppConstants.appName,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'IoT Control Application',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
