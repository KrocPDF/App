import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_limits.dart';
import '../../home/domain/tool_item.dart';

class ToolFlowScreen extends StatefulWidget {
  final String toolId;
  final String? format;

  const ToolFlowScreen({
    super.key,
    required this.toolId,
    this.format,
  });

  @override
  State<ToolFlowScreen> createState() => _ToolFlowScreenState();
}

class _ToolFlowScreenState extends State<ToolFlowScreen> {
  int _currentStepIndex = 0;

  static const List<String> _steps = [
    'Select files',
    'Options',
    'Progress',
    'Result',
  ];

  @override
  Widget build(BuildContext context) {
    final tool = ToolItem.findById(widget.toolId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = theme.colorScheme.outline;

    final toolTitle = tool?.title ?? 'Tool Flow';
    final formatLabel = widget.format != null ? ' (${widget.format!.toUpperCase()})' : '';

    return Scaffold(
      appBar: AppBar(
        title: Text('$toolTitle$formatLabel'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              // Step Indicator Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  children: List.generate(_steps.length, (index) {
                    final isCurrent = index == _currentStepIndex;
                    final isDone = index < _currentStepIndex;

                    return Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _currentStepIndex = index),
                        child: Column(
                          children: [
                            Text(
                              _steps[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCurrent
                                    ? (isDark ? Colors.white : Colors.black)
                                    : (isDark ? Colors.white38 : Colors.black38),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 2,
                              color: isCurrent || isDone
                                  ? (isDark ? Colors.white : Colors.black)
                                  : borderColor,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Active Step View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: SingleChildScrollView(
                      child: _buildStepContent(context, borderColor, isDark),
                    ),
                  ),
                ),
              ),

              // Step Navigation Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStepIndex > 0)
                      OutlinedButton(
                        onPressed: () => setState(() => _currentStepIndex--),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox.shrink(),
                    if (_currentStepIndex < _steps.length - 1)
                      ElevatedButton(
                        onPressed: () => setState(() => _currentStepIndex++),
                        child: const Text('Next step'),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => setState(() => _currentStepIndex = 0),
                        child: const Text('Start over'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, Color borderColor, bool isDark) {
    switch (_currentStepIndex) {
      case 0:
        return _buildSelectFilesStep(context, borderColor, isDark);
      case 1:
        return _buildOptionsStep(context, borderColor, isDark);
      case 2:
        return _buildProgressStep(context, borderColor, isDark);
      case 3:
        return _buildResultStep(context, borderColor, isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSelectFilesStep(BuildContext context, Color borderColor, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(Icons.file_upload_outlined, size: 30),
        ),
        const SizedBox(height: 16),
        const Text(
          'Choose files',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Max ${AppLimits.formattedLimitMb} per file',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            if (widget.toolId == 'image_to_pdf') {
              context.push('/edit-document');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('File picker not implemented yet (Phase 2).'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          },
          child: Text(widget.toolId == 'image_to_pdf' ? 'Open Page Editor' : 'Choose files'),
        ),
      ],
    );
  }

  Widget _buildOptionsStep(BuildContext context, Color borderColor, bool isDark) {
    return _buildPlaceholder(
      title: 'Options',
      subtitle: 'Options not implemented yet.',
      icon: Icons.tune_outlined,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildProgressStep(BuildContext context, Color borderColor, bool isDark) {
    return _buildPlaceholder(
      title: 'Processing',
      subtitle: 'Processing not implemented yet.',
      icon: Icons.hourglass_empty_outlined,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildResultStep(BuildContext context, Color borderColor, bool isDark) {
    return _buildPlaceholder(
      title: 'Result',
      subtitle: 'Processing not implemented yet.',
      icon: Icons.check_circle_outline,
      borderColor: borderColor,
      isDark: isDark,
    );
  }

  Widget _buildPlaceholder({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color borderColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 26),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
