import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:http/http.dart' as http;

/// Claude API Provider for Flutter AI Toolkit
/// Integrates with Anthropic's Claude API (free tier available)
class ClaudeProvider extends LlmProvider {
  final String apiKey;
  final String model;
  final String? systemPrompt;

  // Claude API endpoint
  static const String _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';

  // Message history
  final List<ChatMessage> _history = [];

  // Listeners for state changes
  final List<VoidCallback> _listeners = [];

  ClaudeProvider({
    required this.apiKey,
    this.model = 'claude-3-5-sonnet-20241022', // Latest Claude 3.5 Sonnet
    this.systemPrompt,
  });

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> value) {
    _history.clear();
    _history.addAll(value);
    _notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) {
    // Add user message to history
    _history.add(ChatMessage(
      origin: MessageOrigin.user,
      text: prompt,
      attachments: attachments,
    ));
    _notifyListeners();

    // Generate response and collect it
    final responseBuffer = StringBuffer();
    return generateStream(prompt, attachments: attachments).map((chunk) {
      responseBuffer.write(chunk);
      return chunk;
    }).handleError((error) {
      debugPrint('Error in sendMessageStream: $error');
    }).transform(StreamTransformer<String, String>.fromHandlers(
      handleDone: (sink) {
        // Add assistant message to history when complete
        _history.add(ChatMessage(
          origin: MessageOrigin.llm,
          text: responseBuffer.toString(),
          attachments: const [],
        ));
        _notifyListeners();
        sink.close();
      },
    ));
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    try {
      // Build messages array from history
      final messages = <Map<String, dynamic>>[];

      // Add conversation history
      for (final message in _history) {
        messages.add({
          'role': message.origin == MessageOrigin.user ? 'user' : 'assistant',
          'content': message.text,
        });
      }

      // Add current prompt
      messages.add({
        'role': 'user',
        'content': prompt,
      });

      // Build request body
      final requestBody = {
        'model': model,
        'max_tokens': 4096,
        'stream': true, // Enable streaming
        'messages': messages,
      };

      // Add system prompt if provided
      if (systemPrompt != null && systemPrompt!.isNotEmpty) {
        requestBody['system'] = systemPrompt!;
      }

      // Make streaming request
      final request = http.Request('POST', Uri.parse(_apiUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
      });
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw Exception('Claude API error: ${streamedResponse.statusCode} - $errorBody');
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // Process complete lines
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6);

            // Skip control messages
            if (data == '[DONE]' || data.isEmpty) continue;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final type = json['type'] as String?;

              // Extract text delta from content blocks
              if (type == 'content_block_delta') {
                final delta = json['delta'] as Map<String, dynamic>?;
                if (delta != null && delta['type'] == 'text_delta') {
                  final text = delta['text'] as String?;
                  if (text != null) {
                    yield text;
                  }
                }
              }
            } catch (e) {
              debugPrint('Error parsing Claude SSE: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Claude API error: $e');
      yield '[Error: Failed to generate response from Claude]';
    }
  }
}
