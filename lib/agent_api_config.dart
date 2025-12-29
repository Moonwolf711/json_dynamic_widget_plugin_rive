// WFL Agent Chat - API Configuration
// Tiered system: Free calls with optional premium API keys

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Available AI providers
enum AIProvider {
  free,      // Free tier (OpenRouter free models)
  claude,    // Anthropic Claude
  openai,    // OpenAI GPT
  groq,      // Groq (fast, free tier available)
  ollama,    // Local Ollama
}

/// Model tiers
enum ModelTier {
  free,      // Free models (Llama, Mistral via OpenRouter)
  fast,      // Fast models (Haiku, GPT-3.5, Groq)
  smart,     // Smart models (Sonnet, GPT-4o)
  max,       // Max models (Opus, GPT-4, o1)
}

/// API configuration with tiered access
class AgentAPIConfig {
  static const String _prefsPrefix = 'wfl_agent_';
  
  // Free tier endpoints
  static const String openRouterFreeUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String claudeUrl = 'https://api.anthropic.com/v1/messages';
  static const String openaiUrl = 'https://api.openai.com/v1/chat/completions';
  
  // Free models (no API key needed or free tier)
  static const Map<String, String> freeModels = {
    'llama-3.1-8b': 'meta-llama/llama-3.1-8b-instruct:free',
    'mistral-7b': 'mistralai/mistral-7b-instruct:free',
    'gemma-2-9b': 'google/gemma-2-9b-it:free',
  };
  
  // Premium models by provider
  static const Map<AIProvider, Map<ModelTier, String>> premiumModels = {
    AIProvider.claude: {
      ModelTier.fast: 'claude-3-haiku-20240307',
      ModelTier.smart: 'claude-sonnet-4-20250514',
      ModelTier.max: 'claude-opus-4-20250514',
    },
    AIProvider.openai: {
      ModelTier.fast: 'gpt-4o-mini',
      ModelTier.smart: 'gpt-4o',
      ModelTier.max: 'o1-preview',
    },
    AIProvider.groq: {
      ModelTier.fast: 'llama-3.1-8b-instant',
      ModelTier.smart: 'llama-3.1-70b-versatile',
      ModelTier.max: 'llama-3.1-405b-reasoning',
    },
  };

  // Current settings
  AIProvider provider = AIProvider.free;
  ModelTier tier = ModelTier.free;
  String? claudeKey;
  String? openaiKey;
  String? groqKey;
  String? openRouterKey;
  String? ollamaUrl;
  
  // Usage tracking
  int freeCallsUsed = 0;
  int freeCallsLimit = 50; // Daily limit for free tier
  DateTime? lastResetDate;

  /// Load config from prefs
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    provider = AIProvider.values[prefs.getInt('${_prefsPrefix}provider') ?? 0];
    tier = ModelTier.values[prefs.getInt('${_prefsPrefix}tier') ?? 0];
    claudeKey = prefs.getString('${_prefsPrefix}claude_key');
    openaiKey = prefs.getString('${_prefsPrefix}openai_key');
    groqKey = prefs.getString('${_prefsPrefix}groq_key');
    openRouterKey = prefs.getString('${_prefsPrefix}openrouter_key');
    ollamaUrl = prefs.getString('${_prefsPrefix}ollama_url') ?? 'http://localhost:11434';
    freeCallsUsed = prefs.getInt('${_prefsPrefix}free_calls') ?? 0;
    
    final lastReset = prefs.getString('${_prefsPrefix}last_reset');
    if (lastReset != null) {
      lastResetDate = DateTime.tryParse(lastReset);
    }
    _checkDailyReset();
  }

  /// Save config to prefs
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefsPrefix}provider', provider.index);
    await prefs.setInt('${_prefsPrefix}tier', tier.index);
    if (claudeKey != null) await prefs.setString('${_prefsPrefix}claude_key', claudeKey!);
    if (openaiKey != null) await prefs.setString('${_prefsPrefix}openai_key', openaiKey!);
    if (groqKey != null) await prefs.setString('${_prefsPrefix}groq_key', groqKey!);
    if (openRouterKey != null) await prefs.setString('${_prefsPrefix}openrouter_key', openRouterKey!);
    if (ollamaUrl != null) await prefs.setString('${_prefsPrefix}ollama_url', ollamaUrl!);
    await prefs.setInt('${_prefsPrefix}free_calls', freeCallsUsed);
    await prefs.setString('${_prefsPrefix}last_reset', DateTime.now().toIso8601String());
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    if (lastResetDate == null || now.day != lastResetDate!.day) {
      freeCallsUsed = 0;
      lastResetDate = now;
    }
  }

  bool get canUseFree => freeCallsUsed < freeCallsLimit;
  int get freeCallsRemaining => freeCallsLimit - freeCallsUsed;
  bool get hasPremiumKey => claudeKey != null || openaiKey != null || groqKey != null;
  
  String get currentModel {
    if (provider == AIProvider.free) {
      return freeModels.values.first;
    }
    return premiumModels[provider]?[tier] ?? freeModels.values.first;
  }
}
