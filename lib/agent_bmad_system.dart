// WFL BMad-Style Multi-Agent System
// Specialized agents that run synchronously to handle complex tasks

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'agent_api_client.dart';
import 'agent_api_config.dart';

/// Agent types in the BMad-style system
enum AgentType {
  orchestrator,    // Routes tasks to appropriate agents
  animator,        // Controls Rive animations
  developer,       // Writes/modifies code
  debugger,        // Analyzes and fixes bugs
  designer,        // UI/UX suggestions
  tester,          // Generates and runs tests
  documenter,      // Creates documentation
  refactorer,      // Improves code structure
}

/// Task result from an agent
class AgentResult {
  final AgentType agent;
  final String output;
  final List<String>? commands;  // Commands to execute
  final Map<String, dynamic>? data;
  final bool success;
  final String? error;

  AgentResult({
    required this.agent,
    required this.output,
    this.commands,
    this.data,
    this.success = true,
    this.error,
  });
}

/// Task to be executed by an agent
class AgentTask {
  final AgentType agent;
  final String prompt;
  final Map<String, dynamic>? context;
  final List<String>? dependencies;

  AgentTask({
    required this.agent,
    required this.prompt,
    this.context,
    this.dependencies,
  });
}

/// BMad-style multi-agent orchestrator
class BMadAgentSystem {
  final AgentAPIClient _apiClient;
  final Function(String)? onLog;
  final Function(AgentType, String)? onAgentStart;
  final Function(AgentResult)? onAgentComplete;

  BMadAgentSystem({
    required AgentAPIConfig config,
    this.onLog,
    this.onAgentStart,
    this.onAgentComplete,
  }) : _apiClient = AgentAPIClient(config);

  /// System prompts for each agent type
  static const Map<AgentType, String> _agentPrompts = {
    AgentType.orchestrator: '''You are the WFL Orchestrator Agent.
Your role is to analyze user requests and break them into specific tasks for specialized agents.
Available agents: animator, developer, debugger, designer, tester, documenter, refactorer.

For each task, output a JSON array like:
[{"agent": "animator", "task": "set mouth to shape 5"}, {"agent": "developer", "task": "add error handling"}]

Keep responses concise. Return ONLY the JSON array.''',

    AgentType.animator: '''You are the WFL Animator Agent.
You control Rive animations with these commands:
- /mouth <0-8> - Set mouth shape
- /head <-45 to 45> - Turn head
- /eyes <0-4> - Set eye state
- /tone <0-3> - Set roast tone
- /talk on/off - Toggle talking
- /play, /pause, /stop - Playback

Analyze requests and return the exact commands to execute.
Format: Return each command on its own line.''',

    AgentType.developer: '''You are the WFL Developer Agent.
You write and modify Dart/Flutter code for the WFL app.
Follow these rules:
- Use existing patterns in the codebase
- Keep code clean and minimal
- Add comments only when necessary
- Return code blocks with file paths

Format:
```dart:path/to/file.dart
// code here
```''',

    AgentType.debugger: '''You are the WFL Debugger Agent.
Analyze errors and provide fixes. Format:
1. ISSUE: What went wrong
2. CAUSE: Why it happened
3. FIX: Exact code changes needed

Be specific and actionable.''',

    AgentType.designer: '''You are the WFL Designer Agent for a FLUTTER desktop app.
IMPORTANT: Only output Flutter/Dart code, never Python or other languages.

Design principles:
- Dark theme: bg=#1E1E1E, secondary=#2D2D30, accent=Colors.blue
- Use Material 3 widgets
- Desktop conventions: dialogs, context menus, keyboard shortcuts

When asked to design UI, return Flutter widgets in dart code blocks:
```dart
class MyWidget extends StatelessWidget {
  // Flutter widget code here
}
```

Never use tkinter, PyQt, or any non-Flutter frameworks.''',

    AgentType.tester: '''You are the WFL Tester Agent.
Generate and analyze tests for WFL functionality.
Types: unit tests, widget tests, integration tests.
Use Flutter test conventions.

Return test code in dart code blocks.''',

    AgentType.documenter: '''You are the WFL Documenter Agent.
Create clear documentation for WFL features.
Include: purpose, usage, parameters, examples.
Use markdown format.''',

    AgentType.refactorer: '''You are the WFL Refactorer Agent.
Improve code structure without changing behavior.
Focus on: readability, DRY, single responsibility.
Return before/after code snippets.''',
  };

  /// Run a single agent with a task
  Future<AgentResult> runAgent(AgentType agent, String task, {Map<String, dynamic>? context}) async {
    onAgentStart?.call(agent, task);
    onLog?.call('[${agent.name}] Starting: $task');

    try {
      final systemPrompt = _agentPrompts[agent] ?? '';
      final contextStr = context != null ? '\n\nContext: ${context.toString()}' : '';

      final response = await _apiClient.chat(
        systemPrompt,
        '$task$contextStr',
      );

      // Parse commands from response
      final commands = _extractCommands(response);

      final result = AgentResult(
        agent: agent,
        output: response,
        commands: commands,
        success: true,
      );

      onAgentComplete?.call(result);
      onLog?.call('[${agent.name}] Complete');

      return result;
    } catch (e) {
      final result = AgentResult(
        agent: agent,
        output: '',
        success: false,
        error: e.toString(),
      );

      onAgentComplete?.call(result);
      onLog?.call('[${agent.name}] Error: $e');

      return result;
    }
  }

  /// Run multiple agents synchronously (in parallel)
  Future<List<AgentResult>> runAgentsSync(List<AgentTask> tasks) async {
    onLog?.call('Running ${tasks.length} agents synchronously...');

    // Group tasks by dependencies
    final independent = tasks.where((t) => t.dependencies == null || t.dependencies!.isEmpty).toList();
    final dependent = tasks.where((t) => t.dependencies != null && t.dependencies!.isNotEmpty).toList();

    // Run independent tasks in parallel
    final results = <AgentResult>[];

    if (independent.isNotEmpty) {
      final futures = independent.map((t) => runAgent(t.agent, t.prompt, context: t.context));
      results.addAll(await Future.wait(futures));
    }

    // Run dependent tasks sequentially
    for (final task in dependent) {
      final result = await runAgent(task.agent, task.prompt, context: task.context);
      results.add(result);
    }

    onLog?.call('All ${tasks.length} agents completed');
    return results;
  }

  /// Parse user request and route to agents
  Future<List<AgentResult>> processRequest(String userRequest, {Map<String, dynamic>? appState}) async {
    onLog?.call('Processing: $userRequest');

    // First, use orchestrator to break down the request
    final orchestratorResult = await runAgent(
      AgentType.orchestrator,
      userRequest,
      context: appState,
    );

    // Parse orchestrator response to get tasks
    final tasks = _parseOrchestratorResponse(orchestratorResult.output);

    if (tasks.isEmpty) {
      // If orchestrator didn't return tasks, try to infer from keywords
      final inferredTasks = _inferTasks(userRequest);
      if (inferredTasks.isNotEmpty) {
        return await runAgentsSync(inferredTasks);
      }
      return [orchestratorResult];
    }

    // Run all tasks synchronously
    return await runAgentsSync(tasks);
  }

  /// Parse orchestrator JSON response
  List<AgentTask> _parseOrchestratorResponse(String response) {
    try {
      // Extract JSON array from response
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) return [];

      final jsonStr = jsonMatch.group(0)!;
      final List<dynamic> parsed = [];

      // Simple JSON parsing (avoid importing dart:convert in widget)
      // The orchestrator returns simple format
      final taskMatches = RegExp(r'"agent"\s*:\s*"(\w+)"[\s\S]*?"task"\s*:\s*"([^"]+)"').allMatches(jsonStr);

      return taskMatches.map((m) {
        final agentName = m.group(1)!;
        final task = m.group(2)!;

        final agent = AgentType.values.firstWhere(
          (a) => a.name == agentName,
          orElse: () => AgentType.developer,
        );

        return AgentTask(agent: agent, prompt: task);
      }).toList();
    } catch (e) {
      debugPrint('Failed to parse orchestrator response: $e');
      return [];
    }
  }

  /// Infer tasks from keywords in request
  List<AgentTask> _inferTasks(String request) {
    final tasks = <AgentTask>[];
    final lower = request.toLowerCase();

    // Animation keywords
    if (lower.contains('mouth') || lower.contains('head') || lower.contains('eye') ||
        lower.contains('talk') || lower.contains('animate') || lower.contains('lip')) {
      tasks.add(AgentTask(agent: AgentType.animator, prompt: request));
    }

    // Development keywords
    if (lower.contains('add') || lower.contains('create') || lower.contains('implement') ||
        lower.contains('build') || lower.contains('make') || lower.contains('code')) {
      tasks.add(AgentTask(agent: AgentType.developer, prompt: request));
    }

    // Debug keywords
    if (lower.contains('fix') || lower.contains('bug') || lower.contains('error') ||
        lower.contains('crash') || lower.contains('broken') || lower.contains('debug')) {
      tasks.add(AgentTask(agent: AgentType.debugger, prompt: request));
    }

    // Design keywords
    if (lower.contains('design') || lower.contains('ui') || lower.contains('ux') ||
        lower.contains('style') || lower.contains('layout') || lower.contains('look')) {
      tasks.add(AgentTask(agent: AgentType.designer, prompt: request));
    }

    // Test keywords
    if (lower.contains('test') || lower.contains('verify') || lower.contains('check')) {
      tasks.add(AgentTask(agent: AgentType.tester, prompt: request));
    }

    // Doc keywords
    if (lower.contains('document') || lower.contains('explain') || lower.contains('readme')) {
      tasks.add(AgentTask(agent: AgentType.documenter, prompt: request));
    }

    // Refactor keywords
    if (lower.contains('refactor') || lower.contains('clean') || lower.contains('improve') ||
        lower.contains('optimize')) {
      tasks.add(AgentTask(agent: AgentType.refactorer, prompt: request));
    }

    return tasks;
  }

  /// Extract executable commands from agent response
  List<String> _extractCommands(String response) {
    final commands = <String>[];

    // Find /commands
    final cmdMatches = RegExp(r'^(/\w+[^\n]*)', multiLine: true).allMatches(response);
    for (final m in cmdMatches) {
      commands.add(m.group(1)!.trim());
    }

    return commands;
  }
}

/// Extension to run agents from chat
extension BMadChatExtension on BMadAgentSystem {
  /// Format results for chat display
  String formatResults(List<AgentResult> results) {
    final buffer = StringBuffer();

    for (final result in results) {
      buffer.writeln('**${result.agent.name.toUpperCase()}**');

      if (result.success) {
        buffer.writeln(result.output);

        if (result.commands != null && result.commands!.isNotEmpty) {
          buffer.writeln('\n**Commands:**');
          for (final cmd in result.commands!) {
            buffer.writeln('`$cmd`');
          }
        }
      } else {
        buffer.writeln('Error: ${result.error}');
      }

      buffer.writeln();
    }

    return buffer.toString().trim();
  }
}
