// WFL Agent Settings Dialog
// Configure API keys and model selection

import 'package:flutter/material.dart';
import 'agent_api_config.dart';

class AgentSettingsDialog extends StatefulWidget {
  final AgentAPIConfig config;
  final VoidCallback onSave;

  const AgentSettingsDialog({
    super.key,
    required this.config,
    required this.onSave,
  });

  @override
  State<AgentSettingsDialog> createState() => _AgentSettingsDialogState();
}

class _AgentSettingsDialogState extends State<AgentSettingsDialog> {
  late TextEditingController _claudeController;
  late TextEditingController _openaiController;
  late TextEditingController _groqController;
  late TextEditingController _ollamaController;

  @override
  void initState() {
    super.initState();
    _claudeController = TextEditingController(text: widget.config.claudeKey ?? '');
    _openaiController = TextEditingController(text: widget.config.openaiKey ?? '');
    _groqController = TextEditingController(text: widget.config.groqKey ?? '');
    _ollamaController = TextEditingController(text: widget.config.ollamaUrl ?? 'http://localhost:11434');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF252526),
      title: const Row(
        children: [
          Icon(Icons.settings, color: Colors.blue),
          SizedBox(width: 8),
          Text('Agent Settings', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Usage stats
              _buildUsageCard(),
              const SizedBox(height: 16),
              
              // Provider selection
              _buildProviderSection(),
              const SizedBox(height: 16),
              
              // Model tier
              _buildTierSection(),
              const SizedBox(height: 16),
              
              // API Keys
              _buildAPIKeysSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildUsageCard() {
    final remaining = widget.config.freeCallsRemaining;
    final limit = widget.config.freeCallsLimit;
    final percent = remaining / limit;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.config.hasPremiumKey ? Icons.star : Icons.free_breakfast,
                color: widget.config.hasPremiumKey ? Colors.amber : Colors.green,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.config.hasPremiumKey ? 'Premium Active' : 'Free Tier',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          if (!widget.config.hasPremiumKey) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation(
                percent > 0.2 ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$remaining / $limit free calls today',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Provider', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AIProvider.values.map((p) {
            final selected = widget.config.provider == p;
            return ChoiceChip(
              label: Text(_providerName(p)),
              selected: selected,
              onSelected: (_) => setState(() => widget.config.provider = p),
              selectedColor: Colors.blue,
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTierSection() {
    if (widget.config.provider == AIProvider.free) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Model Tier', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [ModelTier.fast, ModelTier.smart, ModelTier.max].map((t) {
            final selected = widget.config.tier == t;
            return ChoiceChip(
              label: Text(_tierName(t)),
              selected: selected,
              onSelected: (_) => setState(() => widget.config.tier = t),
              selectedColor: _tierColor(t),
              labelStyle: TextStyle(
                color: selected ? Colors.white : Colors.grey,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          'Model: ${widget.config.currentModel}',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAPIKeysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('API Keys (optional)', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        _buildKeyField('Claude', _claudeController, 'sk-ant-...'),
        _buildKeyField('OpenAI', _openaiController, 'sk-...'),
        _buildKeyField('Groq', _groqController, 'gsk_...'),
        _buildKeyField('Ollama URL', _ollamaController, 'http://localhost:11434'),
      ],
    );
  }

  Widget _buildKeyField(String label, TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        obscureText: label != 'Ollama URL',
        style: const TextStyle(color: Colors.white, fontSize: 12),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 11),
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          isDense: true,
        ),
      ),
    );
  }

  String _providerName(AIProvider p) => switch (p) {
    AIProvider.free => '🆓 Free',
    AIProvider.claude => '🟣 Claude',
    AIProvider.openai => '🟢 OpenAI',
    AIProvider.groq => '⚡ Groq',
    AIProvider.ollama => '🦙 Ollama',
  };

  String _tierName(ModelTier t) => switch (t) {
    ModelTier.free => 'Free',
    ModelTier.fast => '⚡ Fast',
    ModelTier.smart => '🧠 Smart',
    ModelTier.max => '🚀 Max',
  };

  Color _tierColor(ModelTier t) => switch (t) {
    ModelTier.free => Colors.green,
    ModelTier.fast => Colors.blue,
    ModelTier.smart => Colors.purple,
    ModelTier.max => Colors.orange,
  };

  void _save() {
    widget.config.claudeKey = _claudeController.text.isEmpty ? null : _claudeController.text;
    widget.config.openaiKey = _openaiController.text.isEmpty ? null : _openaiController.text;
    widget.config.groqKey = _groqController.text.isEmpty ? null : _groqController.text;
    widget.config.ollamaUrl = _ollamaController.text;
    widget.config.save();
    widget.onSave();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _claudeController.dispose();
    _openaiController.dispose();
    _groqController.dispose();
    _ollamaController.dispose();
    super.dispose();
  }
}
