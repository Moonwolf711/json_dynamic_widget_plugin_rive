// WFL Agent API Client
// Handles free and premium tier API calls

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_api_config.dart';

class AgentAPIClient {
  final AgentAPIConfig config;
  
  AgentAPIClient(this.config);

  /// Main entry point - auto-selects best available option
  Future<String> chat(String systemPrompt, String userMessage) async {
    // Try premium first if available and selected
    if (config.provider != AIProvider.free && config.hasPremiumKey) {
      return _callPremium(systemPrompt, userMessage);
    }
    
    // Fall back to free tier
    if (config.canUseFree) {
      return _callFree(systemPrompt, userMessage);
    }
    
    throw Exception('Daily free limit reached (${config.freeCallsLimit}). Add an API key for unlimited access.');
  }

  /// Call free tier (OpenRouter free models)
  Future<String> _callFree(String systemPrompt, String userMessage) async {
    config.freeCallsUsed++;
    await config.save();

    final response = await http.post(
      Uri.parse(AgentAPIConfig.openRouterFreeUrl),
      headers: {
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://wfl.app',
        'X-Title': 'WFL Agent',
      },
      body: jsonEncode({
        'model': AgentAPIConfig.freeModels['llama-3.1-8b'],
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 500,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Free API error: ${response.statusCode}');
  }

  /// Call premium tier based on provider
  Future<String> _callPremium(String systemPrompt, String userMessage) async {
    switch (config.provider) {
      case AIProvider.claude:
        return _callClaude(systemPrompt, userMessage);
      case AIProvider.openai:
        return _callOpenAI(systemPrompt, userMessage);
      case AIProvider.groq:
        return _callGroq(systemPrompt, userMessage);
      case AIProvider.ollama:
        return _callOllama(systemPrompt, userMessage);
      default:
        return _callFree(systemPrompt, userMessage);
    }
  }

  Future<String> _callClaude(String systemPrompt, String userMessage) async {
    final key = config.claudeKey;
    if (key == null || key.isEmpty) throw Exception('Claude API key not set');

    final response = await http.post(
      Uri.parse(AgentAPIConfig.claudeUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': config.currentModel,
        'max_tokens': 1024,
        'system': systemPrompt,
        'messages': [{'role': 'user', 'content': userMessage}],
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['content'][0]['text'] as String;
    }
    throw Exception('Claude API error: ${response.statusCode}');
  }

  Future<String> _callOpenAI(String systemPrompt, String userMessage) async {
    final key = config.openaiKey;
    if (key == null || key.isEmpty) throw Exception('OpenAI API key not set');

    final response = await http.post(
      Uri.parse(AgentAPIConfig.openaiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': config.currentModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 1024,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('OpenAI API error: ${response.statusCode}');
  }

  Future<String> _callGroq(String systemPrompt, String userMessage) async {
    final key = config.groqKey;
    if (key == null || key.isEmpty) throw Exception('Groq API key not set');

    final response = await http.post(
      Uri.parse(AgentAPIConfig.groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': config.currentModel,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'max_tokens': 1024,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    }
    throw Exception('Groq API error: ${response.statusCode}');
  }

  Future<String> _callOllama(String systemPrompt, String userMessage) async {
    final url = config.ollamaUrl ?? 'http://localhost:11434';
    
    final response = await http.post(
      Uri.parse('$url/api/chat'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'llama3.1',
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'stream': false,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message']['content'] as String;
    }
    throw Exception('Ollama error: ${response.statusCode}');
  }
}
