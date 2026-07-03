import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'dart:js' as js;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lumina AI Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF070B19), // Dark space theme
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1), // Indigo
          secondary: Color(0xFFEC4899), // Pink
          surface: Color(0xFF1E293B), // Slate card
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({super.key});

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  final TextEditingController _inputController = TextEditingController();
  final String _apiUrl = 'http://127.0.0.1:5000';
  
  String _activeTab = "Home"; // "Home", "Translator", "About", "Subtitles"
  String _translatedText = "";
  String _selectedSourceLang = "auto";
  String _selectedTargetLang = "es";
  String _currentMode = "Text";
  String _selectedTone = "Original";
  bool _isLoading = false;
  
  // Real-time Web Speech Recognition variables
  bool _isListening = false;
  String _speechStatus = "Tap Mic to Start Speaking";
  
  // Subtitles customizer variables
  int _subtitleFontSize = 24;
  double _subtitleOpacity = 0.85;
  String _subOriginalText = "Waiting for speaker voice...";
  String _subTranslatedText = "Real-time subtitles will render here...";
  
  // AI Insights and ML Metrics
  Map<String, dynamic> _analysisScores = {};
  String _dominantSentiment = "";
  List<dynamic> _flashcards = [];
  double _mlConfidence = 0.0;
  double _latency = 0.0;
  String _engineInfo = "";
  
  List<dynamic> _history = [];
  Map<String, String> _languages = {
    'auto': 'Auto Detect',
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'hi': 'Hindi',
    'mr': 'Marathi',
    'bn': 'Bengali',
  };

  @override
  void initState() {
    super.initState();
    _fetchLanguages();
    _fetchHistory();
    _injectSpeechRecognitionJS();
  }

  // Fetch languages dynamically from Flask backend
  Future<void> _fetchLanguages() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/languages'));
      if (response.statusCode == 200) {
        setState(() {
          _languages = Map<String, String>.from(json.decode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Error fetching languages: $e");
    }
  }

  // Inject chrome webkitSpeechRecognition API scripts dynamically
  void _injectSpeechRecognitionJS() {
    try {
      js.context.callMethod('eval', ["""
        window.startSpeechRecognition = function(onResultCallback, onEndCallback, isContinuous) {
          var SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
          if (!SpeechRecognition) {
            alert("Speech recognition is not supported in this browser. Please use Google Chrome.");
            return;
          }
          window.recognitionInstance = new SpeechRecognition();
          window.recognitionInstance.lang = 'en-US';
          window.recognitionInstance.interimResults = false;
          window.recognitionInstance.continuous = isContinuous || false;
          window.recognitionInstance.maxAlternatives = 1;
          
          window.recognitionInstance.onresult = function(event) {
            var resultIndex = event.resultIndex;
            var text = event.results[resultIndex][0].transcript;
            onResultCallback(text);
          };
          window.recognitionInstance.onerror = function(event) {
            console.error("Speech Recognition Error: ", event.error);
            onResultCallback("Speech recognition error: " + event.error);
          };
          window.recognitionInstance.onend = function() {
            onEndCallback();
          };
          window.recognitionInstance.start();
        };
        window.stopSpeechRecognition = function() {
          if (window.recognitionInstance) {
            window.recognitionInstance.stop();
          }
        };
      """]);
    } catch (e) {
      debugPrint("JS injection error: $e");
    }
  }

  // Toggle Live Speech Recording (Workspace Mode)
  void _toggleListening() {
    if (!_isListening) {
      try {
        setState(() {
          _isListening = true;
          _speechStatus = "Listening... Speak clearly into your mic";
        });
        js.context.callMethod('startSpeechRecognition', [
          js.allowInterop((resultText) {
            setState(() {
              _inputController.text = resultText;
              _speechStatus = "Captured: $resultText";
            });
            _translateText();
          }),
          js.allowInterop(() {
            setState(() {
              _isListening = false;
              _speechStatus = "Finished listening. Click mic to speak again.";
            });
          }),
          false // Not continuous for text input
        ]);
      } catch (e) {
        setState(() {
          _isListening = false;
          _speechStatus = "Error launching Web mic recorder.";
        });
      }
    } else {
      try {
        js.context.callMethod('stopSpeechRecognition');
      } catch (_) {}
      setState(() {
        _isListening = false;
        _speechStatus = "Stopped recording.";
      });
    }
  }

  // Toggle Live Subtitle Listening (Continuous Overlay Mode)
  void _toggleSubtitleListening() {
    if (!_isListening) {
      try {
        setState(() {
          _isListening = true;
          _subOriginalText = "Listening continuously... speak into your microphone.";
        });
        
        js.context.callMethod('startSpeechRecognition', [
          js.allowInterop((resultText) {
            setState(() {
              _subOriginalText = resultText;
            });
            _translateSubtitles(resultText);
          }),
          js.allowInterop(() {
            setState(() {
              _isListening = false;
            });
          }),
          true // Enable continuous recognition for subtitles stream
        ]);
      } catch (e) {
        setState(() {
          _isListening = false;
          _subOriginalText = "Error starting live subtitle capture.";
        });
      }
    } else {
      try {
        js.context.callMethod('stopSpeechRecognition');
      } catch (_) {}
      setState(() {
        _isListening = false;
        _subOriginalText = "Subtitling stopped.";
      });
    }
  }

  Future<void> _translateSubtitles(String text) async {
    if (text.startsWith("Speech recognition error:")) {
      setState(() {
        _subTranslatedText = text;
      });
      return;
    }
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'source_lang': _selectedSourceLang,
          'target_lang': _selectedTargetLang,
          'mode': 'Subtitles',
          'tone_modifier': 'Original',
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _subTranslatedText = data['translated_text'];
        });
      }
    } catch (e) {
      setState(() {
        _subTranslatedText = "Failed to translate subtitles.";
      });
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/history'));
      if (response.statusCode == 200) {
        setState(() {
          _history = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
  }

  Future<void> _translateText() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'source_lang': _selectedSourceLang,
          'target_lang': _selectedTargetLang,
          'mode': _currentMode,
          'tone_modifier': _selectedTone,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _translatedText = data['translated_text'];
          _analysisScores = data['analysis']?['scores'] ?? {};
          _dominantSentiment = data['analysis']?['dominant'] ?? "";
          _flashcards = data['flashcards'] ?? [];
          _mlConfidence = (data['ml_confidence'] ?? 0.0).toDouble();
          _latency = (data['latency'] ?? 0.0).toDouble();
          _engineInfo = data['engine'] ?? "";
        });
        _fetchHistory();
      } else {
        setState(() {
          _translatedText = "Error translating text.";
        });
      }
    } catch (e) {
      setState(() {
        _translatedText = "Failed to connect to API backend.";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _clearHistory() async {
    try {
      await http.post(Uri.parse('$_apiUrl/clear_history'));
      setState(() {
        _history.clear();
      });
    } catch (e) {
      debugPrint("Error clearing history: $e");
    }
  }

  Future<void> _pickAndUploadFile(String endpoint, String modeName) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: modeName == "PDF" 
          ? FileType.custom 
          : (modeName == "Video" ? FileType.video : (modeName == "Speech" ? FileType.audio : FileType.image)),
      allowedExtensions: modeName == "PDF" ? ['pdf'] : null,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _isLoading = true;
        _currentMode = modeName;
      });

      try {
        var request = http.MultipartRequest('POST', Uri.parse('$_apiUrl/$endpoint'));
        request.fields['target_lang'] = _selectedTargetLang;
        request.fields['source_lang'] = _selectedSourceLang;
        
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            result.files.single.bytes!,
            filename: result.files.single.name,
          ),
        );

        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _inputController.text = data['original_text'];
            _translatedText = data['translated_text'];
            _analysisScores = data['analysis']?['scores'] ?? {};
            _dominantSentiment = data['analysis']?['dominant'] ?? "";
            _flashcards = data['flashcards'] ?? [];
            _mlConfidence = (data['ml_confidence'] ?? 0.0).toDouble();
            _latency = (data['latency'] ?? 0.0).toDouble();
            _engineInfo = data['engine'] ?? "";
          });
          _fetchHistory();
        } else {
          showSnackBar("Failed to translate uploaded file.");
        }
      } catch (e) {
        showSnackBar("Error connecting to upload API: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playTts() {
    if (_translatedText.isEmpty) return;
    try {
      final String audioUrl = '$_apiUrl/tts?text=${Uri.encodeComponent(_translatedText)}&lang=$_selectedTargetLang';
      var audio = js.JsObject(js.context['Audio'], [audioUrl]);
      audio.callMethod('play');
      showSnackBar("🔊 Playing audio...");
    } catch (e) {
      showSnackBar("Audio playback error: $e");
    }
  }

  void showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.8, -0.8),
            radius: 1.6,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              if (_activeTab != "Subtitles") _buildTopNavBar(),
              
              // Page Router
              Expanded(
                child: Row(
                  children: [
                    // Main Content Router
                    Expanded(
                      flex: 3,
                      child: _buildPageBody(),
                    ),
                    
                    // Sidebar
                    if (_activeTab == "Translator") _buildSidebarHistory(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1224).withOpacity(0.8),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFFEC4899)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.blur_on, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(
                "Lumina AI Hub",
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildNavButton("Home", Icons.home_outlined),
              _buildNavButton("Translator", Icons.translate_outlined),
              _buildNavButton("About", Icons.info_outline),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String tabName, IconData icon) {
    final isSelected = _activeTab == tabName;
    return GestureDetector(
      onTap: () {
        if (_isListening) {
          try { js.context.callMethod('stopSpeechRecognition'); } catch (_) {}
          setState(() { _isListening = false; });
        }
        setState(() => _activeTab = tabName);
      },
      child: Container(
        margin: const EdgeInsets.only(left: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF6366F1) : Colors.white60),
            const SizedBox(width: 8),
            Text(
              tabName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageBody() {
    switch (_activeTab) {
      case "Home":
        return _buildWelcomeLandingPage();
      case "About":
        return _buildAboutCreatorPage();
      case "Translator":
        return _buildTranslatorWorkspace();
      default:
        return _buildWelcomeLandingPage();
    }
  }

  // 1. Welcome Page / Landing
  Widget _buildWelcomeLandingPage() {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF6366F1).withOpacity(0.2), const Color(0xFFEC4899).withOpacity(0.2)],
                  ),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4), width: 2),
                ),
                child: const Icon(Icons.psychology, size: 80, color: Color(0xFFEC4899)),
              ),
              const SizedBox(height: 32),
              Text(
                "Welcome to Lumina AI Hub",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFFEC4899).withOpacity(0.3)),
                ),
                child: Text(
                  "Created by Ssamarth Kanade",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFBCFE8),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "An extraordinary, multi-modal translator ecosystem utilizing next-generation text tone modification,\nimage scanning (OCR), smart document translation, and live browser voice detection.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  height: 1.6,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 40),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLandingFeatureCard("Multi-Tone Adjuster", Icons.auto_awesome, "Formally or creatively shift text tone on demand."),
                  const SizedBox(width: 20),
                  _buildLandingFeatureCard("Document (PDF) Reader", Icons.picture_as_pdf, "Instantly parse and translate scanned documents."),
                  const SizedBox(width: 20),
                  _buildLandingFeatureCard("Live Subtitle Overlay", Icons.closed_caption_off, "Overlay translations directly on Google Meet/Zoom calls."),
                ],
              ),
              const SizedBox(height: 48),
              
              SizedBox(
                width: 220,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => setState(() => _activeTab = "Translator"),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Enter Workspace", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandingFeatureCard(String title, IconData icon, String desc) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: const Color(0xFF6366F1)),
          const SizedBox(height: 14),
          Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.white30, height: 1.4)),
        ],
      ),
    );
  }

  // 2. About Creator Page
  Widget _buildAboutCreatorPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "About the Developer",
                  style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Divider(color: Colors.white10, height: 16),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: const NetworkImage('profile.jpg'),
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Ssamarth Kanade", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Text("Data Scientist, Data Analyst & AI/ML Engineer", style: TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const Text(
                            "Hi! I am Ssamarth Kanade, a Data Scientist and AI/ML Engineer. This translator ecosystem is a portfolio project designed to showcase dynamic natural language processing (NLP), data analytics, and backend integration.",
                            style: TextStyle(fontSize: 12.5, height: 1.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "Portfolio Project Details:",
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildAboutBulletPoint("NLP & Tone Shifting Models", "Advanced text processing, sentiment/emotion models, and dynamic vocabulary extraction systems."),
                _buildAboutBulletPoint("Data Storage & Analytics", "SQLite database pipeline tracking translation history logs and logs metrics in real-time."),
                _buildAboutBulletPoint("Flutter (Web Client)", "A clean, modern user interface showcasing interactive data structures and browser JS integration."),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                    icon: const Icon(Icons.code, size: 14, color: Color(0xFF6366F1)),
                    label: const Text("View Project Code", style: TextStyle(color: Color(0xFF6366F1), fontSize: 12)),
                    onPressed: () => showSnackBar("Code files located inside: F:\\Language Translator"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAboutBulletPoint(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFFEC4899)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.4, color: const Color(0xFFCBD5E1)),
                children: [
                  TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // 4. Main Translator Workspace
  Widget _buildTranslatorWorkspace() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildModeWorkspaceButton("Text", Icons.edit_note),
                  const SizedBox(width: 8),
                  _buildModeWorkspaceButton("Document (PDF)", Icons.article_outlined),
                  const SizedBox(width: 8),
                  _buildModeWorkspaceButton("Image OCR", Icons.document_scanner_outlined),
                  const SizedBox(width: 8),
                  _buildModeWorkspaceButton("Video File", Icons.video_file_outlined),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text("Creator: Ssamarth Kanade", style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFA5B4FC))),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "INPUT SOURCE",
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedSourceLang,
                                dropdownColor: const Color(0xFF0F172A),
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                items: _languages.entries.map((entry) {
                                  return DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedSourceLang = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 12),
                        Expanded(
                          child: Stack(
                            children: [
                              TextField(
                                controller: _inputController,
                                maxLines: null,
                                expands: true,
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5, color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Type text, upload files, or click the microphone to speak...",
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.white24),
                                  contentPadding: EdgeInsets.only(bottom: 45),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Tooltip(
                                  message: _isListening ? "Stop Recording" : "Speak to Translate",
                                  child: GestureDetector(
                                    onTap: _toggleListening,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _isListening 
                                            ? const Color(0xFFEC4899).withOpacity(0.2) 
                                            : const Color(0xFF6366F1).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _isListening ? const Color(0xFFEC4899) : const Color(0xFF6366F1),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        _isListening ? Icons.mic : Icons.mic_none, 
                                        size: 18, 
                                        color: _isListening ? const Color(0xFFEC4899) : const Color(0xFF6366F1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              if (_isListening)
                                Positioned(
                                  bottom: 6,
                                  left: 0,
                                  child: Text(
                                    "🎙️ Listening Live...",
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: const Color(0xFFEC4899), fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "AI TRANSLATION",
                              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                            ),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTargetLang,
                                dropdownColor: const Color(0xFF0F172A),
                                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                items: _languages.entries
                                    .where((entry) => entry.key != 'auto')
                                    .map((entry) {
                                  return DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setState(() => _selectedTargetLang = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white10, height: 12),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                                  child: Text(
                                    _translatedText.isNotEmpty
                                        ? _translatedText
                                        : "Translation results will display here...",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: _translatedText.isNotEmpty ? Colors.white : Colors.white24,
                                    ),
                                  ),
                                ),
                        ),
                        if (_translatedText.isNotEmpty) ...[
                          const Divider(color: Colors.white10, height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.psychology_outlined, size: 14, color: Color(0xFFEC4899)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Accuracy: $_mlConfidence% | Speed: ${_latency}s",
                                    style: GoogleFonts.plusJakartaSans(fontSize: 10, color: const Color(0xFFEC4899), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up, color: Color(0xFF6366F1), size: 20),
                                onPressed: _playTts,
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_currentMode == "Text") ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Text(
                    "AI TONE:",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildToneChip("Original"),
                          _buildToneChip("Professional/Formal"),
                          _buildToneChip("Creative/Poetic"),
                          _buildToneChip("Urgent/Alert"),
                          _buildToneChip("Happy/Friendly"),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (_translatedText.isNotEmpty && !_isLoading) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("TONE ANALYSIS", style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(height: 6),
                        Text(
                          _dominantSentiment.isNotEmpty ? "Style: $_dominantSentiment" : "Analyzing...",
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEC4899)),
                        ),
                        const SizedBox(height: 8),
                        ..._analysisScores.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e.key, style: const TextStyle(fontSize: 9, color: Colors.white70)),
                                    Text("${(e.value * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 9, color: Colors.white54)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                LinearProgressIndicator(
                                  value: e.value,
                                  backgroundColor: Colors.white10,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                                  minHeight: 2.5,
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("KEY VOCABULARY TERMS", style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(height: 10),
                        Row(
                          children: _flashcards.map<Widget>((card) {
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [const Color(0xFF1E293B), const Color(0xFF0F172A).withOpacity(0.8)],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      card['word'] ?? '',
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFA5B4FC)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(card['type'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.white30)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _translateText,
              child: Text("Process AI Translation", style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeWorkspaceButton(String modeName, IconData icon) {
    final isSelected = _currentMode == modeName;
    return GestureDetector(
      onTap: () {
        if (modeName == "PDF") {
          _pickAndUploadFile("translate_pdf", "PDF");
        } else if (modeName == "Image OCR") {
          _pickAndUploadFile("translate_ocr", "OCR");
        } else if (modeName == "Video File") {
          _pickAndUploadFile("translate_video", "Video");
        } else {
          setState(() {
            _currentMode = modeName;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? const Color(0xFF6366F1) : Colors.white60),
            const SizedBox(width: 8),
            Text(modeName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white60)),
          ],
        ),
      ),
    );
  }

  Widget _buildToneChip(String tone) {
    final isSelected = _selectedTone == tone;
    return GestureDetector(
      onTap: () => setState(() => _selectedTone = tone),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEC4899).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFEC4899) : Colors.white10,
          ),
        ),
        child: Text(
          tone.split('/').first,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFFEC4899) : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarHistory() {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1224),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("History Logs", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent, size: 20),
                onPressed: _clearHistory,
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Expanded(
            child: _history.isEmpty
                ? const Center(child: Text("No translations yet.", style: TextStyle(color: Colors.white24, fontSize: 13)))
                : ListView.builder(
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      final item = _history[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(item['mode'] ?? 'Text', style: const TextStyle(fontSize: 9, color: Color(0xFFA5B4FC))),
                                ),
                                Text(
                                  "${item['source_lang'].toUpperCase()} ➔ ${item['target_lang'].toUpperCase()}",
                                  style: const TextStyle(fontSize: 10, color: Colors.white30),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item['original_text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                            Text(item['translated_text'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
