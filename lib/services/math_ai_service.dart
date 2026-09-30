import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/math_step.dart';

/// Sends an image of mathematics to a vision-capable model and parses the
/// answer into a [RecognitionResult].
///
/// Configuration comes from `--dart-define`, so no secret ever lands in the
/// repository:
///
/// ```sh
/// flutter run \
///   --dart-define=MATH_AI_API_KEY=sk-xxx \
///   --dart-define=MATH_AI_ENDPOINT=https://api.openai.com/v1/chat/completions \
///   --dart-define=MATH_AI_MODEL=gpt-4o-mini
/// ```
class MathAiService {
  MathAiService({
    required this.apiKey,
    required this.endpoint,
    required this.model,
    http.Client? client,
  }) : _client = client ?? http.Client();

  factory MathAiService.fromEnvironment() => MathAiService(
        apiKey: const String.fromEnvironment('MATH_AI_API_KEY'),
        endpoint: const String.fromEnvironment(
          'MATH_AI_ENDPOINT',
          defaultValue: 'https://api.openai.com/v1/chat/completions',
        ),
        model: const String.fromEnvironment(
          'MATH_AI_MODEL',
          defaultValue: 'gpt-4o-mini',
        ),
      );

  final String apiKey;
  final String endpoint;
  final String model;
  final http.Client _client;

  static const String _systemPrompt = '''
You are MathChanger, an expert at reading mathematics from images.
Return ONLY minified JSON shaped like:
{"steps":[{"index":1,"latex":"...","explanation":"..."}],"rawText":"..."}
Rules:
- Transcribe each line of working as one step, in order.
- "latex" must be valid LaTeX with no surrounding delimiters.
- "explanation" is a short plain-language note, or null.
- If the image holds no mathematics, return {"steps":[]}.
''';

  Future<RecognitionResult> analyseImage(File image) async {
    if (apiKey.isEmpty) {
      throw StateError(
        'MATH_AI_API_KEY is empty. Pass it via --dart-define=MATH_AI_API_KEY=...',
      );
    }

    final bytes = await image.readAsBytes();
    final dataUri = 'data:${_guessMimeType(image.path)};base64,'
        '${base64Encode(bytes)}';

    final response = await _client.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'temperature': 0,
        'response_format': {'type': 'json_object'},
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': 'Convert the mathematics in this image to LaTeX.',
              },
              {
                'type': 'image_url',
                'image_url': {'url': dataUri},
              },
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Model request failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return RecognitionResult.fromJson(
      jsonDecode(_extractContent(decoded)) as Map<String, dynamic>,
    );
  }

  static String _extractContent(Map<String, dynamic> body) {
    final choices = body['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = choices.first;
      if (message is Map && message['message'] is Map) {
        final content = (message['message'] as Map)['content'];
        if (content is String) return content;
      }
    }
    throw FormatException('Unexpected model response: $body');
  }

  static String _guessMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
