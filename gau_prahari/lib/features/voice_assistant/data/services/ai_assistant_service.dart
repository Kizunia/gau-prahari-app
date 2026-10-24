import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/config/ai_config.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/services/assistant_responder.dart';
import '../../../collar_import/data/repositories/file_collar_data_provider.dart';
import '../../../collar_import/domain/entities/collar_telemetry.dart';
import '../../../cow_selection/domain/repositories/cow_repository.dart';
import '../../../cow_selection/data/repositories/cow_repository_impl.dart';

/// Concrete AI Assistant service communicating with Google Gemini API.
///
/// Supports free tier Gemini models (e.g. gemini-3-flash-preview, gemini-3.5-flash),
/// multi-turn conversation memory, screen-state contextualization,
/// dynamic herd knowledge injection, and localized direct answers.
class AiAssistantService implements AssistantResponder {
  final http.Client _httpClient;
  final String? _apiKeyOverride;
  final CowRepository? _cowRepository;
  static const String prefApiKey = 'gemini_api_key';

  AiAssistantService({
    http.Client? httpClient,
    String? apiKey,
    CowRepository? cowRepository,
  })  : _httpClient = httpClient ?? http.Client(),
        _apiKeyOverride = apiKey,
        _cowRepository = cowRepository;

  /// Cleans and sanitizes user-entered API keys by stripping quotes,
  /// semicolons, placeholder artifacts, prefixes, and whitespace.
  static String sanitizeApiKey(String? raw) {
    if (raw == null) return '';
    var key = raw.trim();
    // Strip trailing semicolon
    if (key.endsWith(';')) {
      key = key.substring(0, key.length - 1).trim();
    }
    // Strip surrounding quotes
    if ((key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))) {
      key = key.substring(1, key.length - 1).trim();
    }
    // Strip prefixes like "gemini_api_key = ", "key: ", "api_key="
    final prefixRegex = RegExp(
      r'^(?:static\s+const\s+String\s+)?(?:gemini_?api_?key|api_?key|key)\s*[:=]\s*',
      caseSensitive: false,
    );
    key = key.replaceAll(prefixRegex, '').trim();
    // Strip surrounding quotes again if present inside prefix
    if ((key.startsWith('"') && key.endsWith('"')) ||
        (key.startsWith("'") && key.endsWith("'"))) {
      key = key.substring(1, key.length - 1).trim();
    }
    // Strip placeholder artifact if concatenated
    if (key.contains('YOUR_GEMINI_API_KEY_HERE')) {
      key = key.replaceAll('YOUR_GEMINI_API_KEY_HERE', '').trim();
    }
    return key;
  }

  /// Retrieve the active Gemini API key from SharedPreferences, falling back
  /// to the configured [AiConfig.geminiApiKey].
  Future<String> getApiKey() async {
    if (_apiKeyOverride != null) {
      return sanitizeApiKey(_apiKeyOverride);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedKey = prefs.getString(prefApiKey);
      if (storedKey != null) {
        final sanitized = sanitizeApiKey(storedKey);
        if (sanitized.isNotEmpty) {
          return sanitized;
        }
      }
    } catch (e) {
      debugPrint('AiAssistantService getApiKey prefs error: $e');
    }
    return sanitizeApiKey(AiConfig.geminiApiKey);
  }

  /// Store or clear the API key dynamically in SharedPreferences.
  static Future<void> setApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null) {
      await prefs.remove(prefApiKey);
      return;
    }
    final sanitized = sanitizeApiKey(key);
    if (sanitized.isEmpty) {
      await prefs.remove(prefApiKey);
    } else {
      await prefs.setString(prefApiKey, sanitized);
    }
  }

  /// Dynamically loads registered herd animals and their longitudinal telemetry
  /// directly from the repositories and providers.
  Future<String> _buildHerdContext() async {
    try {
      final repo = _cowRepository ?? CowRepositoryImpl();
      final cows = await repo.getAllCows();
      if (cows.isEmpty) return '';

      final buffer = StringBuffer('\nREGISTERED ANIMALS ON THIS FARM (LIVE DATABASE):\n');
      for (final cow in cows) {
        final nameStr = (cow.name != null && cow.name!.trim().isNotEmpty)
            ? 'Name: "${cow.name}", '
            : (cow.id == 'COW-104' ? 'Name: "Ganga" (COW-104), ' : '');
        buffer.write(
          '- ID: ${cow.id}, ${nameStr}Breed: ${cow.breed}, Age: ${cow.ageYears} years, '
          'Tag: ${cow.tagNumber}, Lactation: ${cow.lactationStage}, Status: ${cow.status}',
        );

        final telemetry = await _getTelemetryForCow(cow.id);
        if (telemetry != null && telemetry.isNotEmpty) {
          buffer.write(
            ' | Live Telemetry (${telemetry.recordCount} days recorded): '
            'Mean Activity: ${telemetry.meanActivity.toStringAsFixed(1)}, '
            'Mean Skin Temp: ${telemetry.meanSkinTemperature.toStringAsFixed(1)}°C, '
            'Mean THI: ${telemetry.meanThi.toStringAsFixed(1)}',
          );
        }
        buffer.writeln();
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Error building dynamic herd context: $e');
      return '';
    }
  }

  /// Dynamically fetches collar telemetry records for the specified cow.
  Future<CollarHistory?> _getTelemetryForCow(String cowId) async {
    try {
      final cleanId = cowId.toLowerCase().replaceAll('-', '_');
      final provider = FileCollarDataProvider();
      try {
        return await provider.loadFromAsset(
          'assets/data/collar_$cleanId.json',
          expectedCowId: cowId,
        );
      } catch (_) {}
      try {
        return await provider.loadFromAsset(
          'assets/data/collar_$cleanId.csv',
          expectedCowId: cowId,
        );
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading telemetry for $cowId: $e');
    }
    return null;
  }

  /// Detect whether the query is in Marathi (Devanagari or transliterated Latin script).
  static bool isMarathiQuery(String query) {
    final lower = query.toLowerCase();
    if (RegExp(r'[\u0900-\u097F]').hasMatch(query)) {
      if (lower.contains('आहे') ||
          lower.contains('नाही') ||
          lower.contains('माहिती') ||
          lower.contains('सांगा') ||
          lower.contains('द्या') ||
          lower.contains('कसे') ||
          lower.contains('किती') ||
          lower.contains('बद्दल') ||
          lower.contains('मला')) {
        return true;
      }
    }
    const marathiWords = [
      'mala', 'mahiti', 'sanga', 'baddal', 'badal', 'kiti', 'kasa', 'kase',
      'ahe', 'nahi', 'dya', 'chi', 'cha', 'che', 'dudh', 'doodh',
      'sarv', 'sarva', 'kuthe', 'kadhi', 'tula', 'amhi', 'aamhi', 'ji', 'sabki', 'sabhi'
    ];
    for (final word in marathiWords) {
      if (RegExp(r'\b' + word + r'\b', caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  /// Detect whether the query is in Hindi (Devanagari or transliterated Latin script).
  static bool isHindiQuery(String query) {
    final lower = query.toLowerCase();
    if (RegExp(r'[\u0900-\u097F]').hasMatch(query)) {
      if (lower.contains('है') ||
          lower.contains('नहीं') ||
          lower.contains('जानकारी') ||
          lower.contains('बताओ') ||
          lower.contains('दीजिए') ||
          lower.contains('कैसे') ||
          lower.contains('कितना') ||
          lower.contains('बारे') ||
          lower.contains('मुझे')) {
        return true;
      }
    }
    const hindiWords = [
      'mujhe', 'batao', 'jankari', 'bare', 'kya', 'hai', 'hain', 'nahi',
      'kaise', 'kitna', 'do', 'dijiye', 'kripya'
    ];
    for (final word in hindiWords) {
      if (RegExp(r'\b' + word + r'\b', caseSensitive: false).hasMatch(lower)) {
        return true;
      }
    }
    return false;
  }

  /// System instructions defining Gau-Prahari cattle health domain knowledge,
  /// direct factual answers, conciseness, and strict language matching.
  String _buildSystemInstruction({
    required String query,
    required String languageCode,
    Map<String, dynamic>? screenContext,
    String herdContext = '',
  }) {
    final langName = switch (languageCode) {
      'hi' => 'Hindi (हिंदी)',
      'mr' => 'Marathi (मराठी)',
      _ => 'English',
    };

    String contextSnippet = '';
    if (screenContext != null && screenContext.isNotEmpty) {
      contextSnippet = '\nCURRENT APPLICATION SCREEN CONTEXT:\n';
      screenContext.forEach((key, value) {
        contextSnippet += '- $key: $value\n';
      });
    }

    return '''
You are Gau-Prahari AI Voice Assistant (developed by Codeapex), a versatile, expert, and empathetic voice companion for Indian dairy farmers, livestock owners, and field veterinarians.

BROAD GENERAL-PURPOSE & DOMAIN CAPABILITIES:
1. FULL GENERAL-PURPOSE KNOWLEDGE:
   - You are NOT limited or tightly coupled only to the Gau-Prahari app or mastitis!
   - You are an all-round veterinary, dairy farming, agriculture, and general-purpose AI assistant.
   - When a farmer asks ANY general question, provide a thorough, accurate, and direct general-purpose answer:
     a) Cattle Health & Diseases: If asked about cow diseases (e.g., "मला गाईच्या आजाराबद्दल माहिती हवी आहे", "गाय की बीमारियाँ", "cow diseases"), give an informative breakdown of common bovine diseases (such as Mastitis/स्तनदाह/कासदाह, Foot and Mouth Disease/लाळ-खुरकूत/खुरपकत, Lumpy Skin Disease/गाठींचा आजार/लम्पी, Hemorrhagic Septicemia/घटसर्प, Black Quarter/फऱ्या, Milk Fever/दुग्धज्वर, Bloat/पोटफुगी), key symptoms (fever, reduced milk, loss of appetite, swollen udder), and practical guidance (hygiene, timely vaccination, prompt veterinary consultation).
     b) Dairy Management & Cattle Care: Cattle feeding and fodder (हिरवा चारा, सुका चारा, सायलेज, पशुआहार, खनिज मिश्रण), improving milk yield and fat/SNF, breeding cycles, artificial insemination, pregnancy care, calf rearing, and shed sanitation.
     c) Agriculture & Farming: Crop management, irrigation, seasonal precautions (summer heat stress, monsoon humidity, winter cold), and government farmer schemes (PM-KISAN, Kisan Credit Card, Livestock Insurance).
     d) Everyday & General Knowledge: Answer general life, weather, or educational queries clearly and helpfully.

2. GAU-PRAHARI APP FEATURES & HERD DATA (CONTEXTUAL USE ONLY):
   - You have access to the Gau-Prahari platform tools and live registered herd data:
     * Smart Neck Collar Telemetry: 14-day trends for cow activity, skin temperature, ambient temperature, humidity, and THI (Temperature-Humidity Index).
     * Handheld Milk Tester: Real-time milk measurements including milk temperature, electrical conductivity, pH, somatic cell count (SCC), fat %, and SNF %.
     * Machine Learning: Early risk forecasting (Healthy, Subclinical Mastitis, Clinical Mastitis).
$herdContext$contextSnippet
   - Use this app and herd data IF AND ONLY IF:
     * The user explicitly asks about a specific registered cow (e.g., "Ganga", "COW-104", "COW-101", "माझ्या गाईंची माहिती"), OR
     * The user asks specifically about how the Gau-Prahari app, smart neck collar, or milk tester works.
   - NEVER pivot or force general questions (like cow diseases, feeding, crops, general knowledge) into a promotional pitch for Gau-Prahari! Answer what the user actually asked.

3. CRITICAL ANSWERING DIRECTIVES:
   - ANSWER DIRECTLY: Provide immediate, direct, and factual answers. Never give evasive instructions like "go to another screen" or "please select her name from the list" unless the user explicitly asks for navigation help.
   - SPOKEN CLARITY & COMPLETENESS: Responses are read aloud via Text-to-Speech to farmers. Keep answers clear, well-structured, and conversational (around 3 to 5 informative sentences). ALWAYS finish all sentences and thoughts completely; NEVER leave a sentence cut off or truncated.
   - DYNAMIC & UNBIASED: Do NOT hardcode or constrain your answers. Adapt dynamically to the user's specific query.
   - STRICT LANGUAGE & SCRIPT RULES:
     * If the user asks in Marathi (whether in Devanagari script or transliterated Latin script like "mala mahiti havi ahe", "kiti dudh dete", "Ganga badal sanga"): You MUST reply in pure, natural Marathi (मराठी) using Devanagari script!
     * If the user asks in Hindi (whether in Devanagari script or Hinglish like "gay ki bimariyo ke bare me batao", "doodh kaise badhaye"): You MUST reply in Hindi (हिंदी) using Devanagari script!
     * If the user asks in English: Reply in clear English.
     * If the query language is ambiguous, use $langName.
   - ACTION TRIGGER: If and only if the user specifically requests to scan a cow, open camera, or scan QR tag, confirm and end your answer with: [ACTION:scan_cow].
''';
  }

  @override
  Future<String> respond({
    required String query,
    required String languageCode,
    List<ChatMessage>? conversationContext,
    Map<String, dynamic>? screenContext,
  }) async {
    try {
      final apiKey = await getApiKey();

      if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_API_KEY_HERE') {
        return _missingKeyMessage(languageCode);
      }

      final herdContext = await _buildHerdContext();

      // Try primary model, fallback to secondary model if 404
      try {
        return await _callGemini(
          query: query,
          languageCode: languageCode,
          apiKey: apiKey,
          model: AiConfig.defaultModel,
          conversationContext: conversationContext,
          screenContext: screenContext,
          herdContext: herdContext,
        );
      } on _GeminiModelNotFoundException {
        debugPrint(
          'Primary model ${AiConfig.defaultModel} 404, attempting fallback ${AiConfig.fallbackModel}',
        );
        try {
          return await _callGemini(
            query: query,
            languageCode: languageCode,
            apiKey: apiKey,
            model: AiConfig.fallbackModel,
            conversationContext: conversationContext,
            screenContext: screenContext,
            herdContext: herdContext,
          );
        } catch (fallbackErr) {
          debugPrint('Fallback model error: $fallbackErr');
          return _handleError(fallbackErr, languageCode);
        }
      }
    } catch (e) {
      return _handleError(e, languageCode);
    }
  }

  Future<String> _callGemini({
    required String query,
    required String languageCode,
    required String apiKey,
    required String model,
    List<ChatMessage>? conversationContext,
    Map<String, dynamic>? screenContext,
    String herdContext = '',
  }) async {
    final endpoint = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    // Format previous messages (up to 20 recent messages with alternating roles)
    final contents = _buildContents(
      query: query,
      conversationContext: conversationContext,
    );

    final requestBody = {
      'systemInstruction': {
        'parts': [
          {
            'text': _buildSystemInstruction(
              query: query,
              languageCode: languageCode,
              screenContext: screenContext,
              herdContext: herdContext,
            ),
          },
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
        'thinkingConfig': {
          'thinkingLevel': 'low',
        },
      },
    };

    final response = await _httpClient
        .post(
          endpoint,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode(requestBody),
        )
        .timeout(Duration(seconds: AiConfig.requestTimeoutSeconds));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              if (part['thought'] == true) continue;
              final text = part['text'] as String?;
              if (text != null && text.isNotEmpty) {
                buffer.write(text);
              }
            }
          }
          final fullText = buffer.toString().trim();
          if (fullText.isNotEmpty) {
            return fullText;
          }
        }
      }
      return _emptyReplyMessage(languageCode);
    }

    if (response.statusCode == 404 ||
        response.statusCode == 503 ||
        response.statusCode == 500) {
      throw _GeminiModelNotFoundException(model);
    }

    if (response.statusCode == 429) {
      return _quotaExceededMessage(languageCode);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint(
        'Gemini API Auth Error ${response.statusCode}: ${response.body}',
      );
      return _invalidKeyMessage(languageCode);
    }

    if (response.statusCode == 400) {
      debugPrint(
        'Gemini API 400 Error: ${response.body}',
      );
      final body = response.body.toLowerCase();
      if (body.contains('api key') ||
          body.contains('api_key') ||
          body.contains('key not valid') ||
          body.contains('key expired')) {
        return _invalidKeyMessage(languageCode);
      }
      return _generalErrorMessage(languageCode);
    }

    debugPrint('Gemini API HTTP Error ${response.statusCode}: ${response.body}');
    return _generalErrorMessage(languageCode);
  }

  List<Map<String, dynamic>> _buildContents({
    required String query,
    List<ChatMessage>? conversationContext,
  }) {
    final contents = <Map<String, dynamic>>[];

    if (conversationContext != null && conversationContext.isNotEmpty) {
      // Take up to 20 recent messages
      final recent = conversationContext.length > 20
          ? conversationContext.sublist(conversationContext.length - 20)
          : conversationContext;

      for (int i = 0; i < recent.length; i++) {
        final msg = recent[i];
        final text = msg.content.trim();
        if (text.isEmpty) continue;

        // Skip if this is the very last message and matches the current query
        if (i == recent.length - 1 && msg.isUser && text == query.trim()) {
          continue;
        }

        final role = msg.isUser ? 'user' : 'model';

        // Gemini REST API strictly requires alternating user and model turns
        if (contents.isNotEmpty && contents.last['role'] == role) {
          final lastParts = contents.last['parts'] as List<dynamic>;
          final prevText = lastParts.last['text'] as String;
          lastParts.last['text'] = '$prevText\n$text';
        } else {
          contents.add({
            'role': role,
            'parts': [
              {'text': text},
            ],
          });
        }
      }
    }

    // Append or ensure current query is the final 'user' message
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      final lastParts = contents.last['parts'] as List<dynamic>;
      lastParts.last['text'] = query.trim();
    } else {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': query.trim()},
        ],
      });
    }

    // Ensure first message has role 'user'
    while (contents.isNotEmpty && contents.first['role'] != 'user') {
      contents.removeAt(0);
    }

    return contents;
  }

  String _handleError(dynamic error, String lang) {
    debugPrint('AiAssistantService error: $error');
    if (error is SocketException) {
      return _offlineMessage(lang);
    }
    if (error is TimeoutException) {
      return _timeoutMessage(lang);
    }
    return _generalErrorMessage(lang);
  }

  String _missingKeyMessage(String lang) => switch (lang) {
        'hi' =>
          'कृपया एआई प्रतिक्रियाएं सक्षम करने के लिए अपनी Gemini API कुंजी कॉन्फ़िगर करें। ऊपर कुंजी आइकन दबाएं।',
        'mr' =>
          'कृपया AI प्रतिसाद सक्षम करण्यासाठी आपली Gemini API की कॉन्फिगर करा. वरील की आयकॉन दाबा.',
        _ =>
          'Please configure your Gemini API Key to enable AI responses. Tap the key icon at the top.',
      };

  String _offlineMessage(String lang) => switch (lang) {
        'hi' =>
          'नेटवर्क कनेक्शन त्रुटि। कृपया अपना इंटरनेट कनेक्शन जांचें और पुनः प्रयास करें।',
        'mr' =>
          'नेटवर्क कनेक्शन त्रुटी. कृपया तुमचे इंटरनेट कनेक्शन तपासा आणि पुन्हा प्रयत्न करा.',
        _ =>
          'Network connection error. Please check your internet connection and try again.',
      };

  String _timeoutMessage(String lang) => switch (lang) {
        'hi' => 'सहायक का उत्तर आने में अधिक समय लगा। कृपया पुनः प्रयास करें।',
        'mr' => 'प्रतिसाद मिळण्यास वेळ लागला. कृपया पुन्हा प्रयत्न करा.',
        _ => 'The assistant took too long to respond. Please try again.',
      };

  String _quotaExceededMessage(String lang) => switch (lang) {
        'hi' =>
          'Gemini API अनुरोध सीमा समाप्त हो गई है। कृपया कुछ क्षण बाद पुनः प्रयास करें।',
        'mr' =>
          'Gemini API विनंती मर्यादा गाठली आहे. कृपया थोड्या वेळाने पुन्हा प्रयत्न करा.',
        _ =>
          'Gemini API rate limit reached. Please wait a moment and try again.',
      };

  String _invalidKeyMessage(String lang) => switch (lang) {
        'hi' =>
          'अमान्य Gemini API कुंजी। कृपया Google AI Studio से अपनी सही कुंजी दर्ज करें।',
        'mr' =>
          'अवैध Gemini API की. कृपया Google AI Studio मधून तुमची योग्य की प्रविष्ट करा.',
        _ =>
          'Invalid or unauthorized Gemini API key. Please check your key from Google AI Studio.',
      };

  String _emptyReplyMessage(String lang) => switch (lang) {
        'hi' =>
          'सहायक से कोई उत्तर प्राप्त नहीं हुआ। कृपया अपना प्रश्न पुनः पूछें।',
        'mr' => 'असिस्टंटकडून कोणताही प्रतिसाद मिळाला नाही. कृपया पुन्हा विचारा.',
        _ => 'No response received from assistant. Please try asking again.',
      };

  String _generalErrorMessage(String lang) => switch (lang) {
        'hi' =>
          'एआई सहायक से कनेक्ट करने में समस्या हुई। कृपया पुनः प्रयास करें।',
        'mr' => 'AI असिस्टंटशी कनेक्ट करताना समस्या आली. कृपया पुन्हा प्रयत्न करा.',
        _ => 'Unable to connect to AI assistant. Please try again.',
      };
}

class _GeminiModelNotFoundException implements Exception {
  final String model;
  _GeminiModelNotFoundException(this.model);
}