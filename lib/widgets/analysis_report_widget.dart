import 'package:flutter/material.dart';

/// Shared analysis report widget used across all game modes
/// Provides consistent formatting for melody comparison results
class AnalysisReportWidget extends StatelessWidget {
  final Map<String, dynamic> scoreData;
  final int? clientRoundTripTime;
  final VoidCallback? onClose;

  const AnalysisReportWidget({
    super.key,
    required this.scoreData,
    this.clientRoundTripTime,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final bool serverComparison = scoreData.containsKey('note_details') ||
        scoreData.containsKey('processing_time_ms') ||
        scoreData.containsKey('matching_runtime_nocom');
    final double? overallScore = scoreData['final_score'] as double?;
    final double? pitchAccuracy = scoreData['pitch_accuracy'] as double?;
    final double? timingAccuracy = scoreData['timing_accuracy'] as double?;
    final double? matchingRuntimeNocom = scoreData['matching_runtime_nocom'] as double?;
    final List<dynamic>? noteDetailsList = scoreData['note_details'] as List<dynamic>?;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with analysis type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                serverComparison ? 'Server Analysis' : 'Offline Analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),

          // Timing metrics
          if (clientRoundTripTime != null || matchingRuntimeNocom != null) ...[
            const SizedBox(height: 8),
            if (clientRoundTripTime != null)
              _buildMetricRow(context, 'Response Time (client→server→client)', clientRoundTripTime!.toDouble(),
                  isMilliseconds: true, isScore: false),
            if (matchingRuntimeNocom != null)
              _buildMetricRow(context, 'Matching Time (server only)', matchingRuntimeNocom,
                  isMilliseconds: true, isScore: false),
          ],

          const Divider(),

          // Overall Score
          if (overallScore != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Overall Score: ${(overallScore * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _getColorForScore(overallScore),
                    ),
              ),
            ),

          // Accuracy Metrics
          if (pitchAccuracy != null) _buildMetricRow(context, 'Pitch Accuracy', pitchAccuracy * 100),
          if (timingAccuracy != null) _buildMetricRow(context, 'Timing Accuracy', timingAccuracy * 100),

          // Additional accuracy metrics if available
          if (scoreData.containsKey('onset_accuracy'))
            _buildMetricRow(context, 'Onset Accuracy', (scoreData['onset_accuracy'] as double) * 100),
          if (scoreData.containsKey('duration_accuracy'))
            _buildMetricRow(context, 'Duration Accuracy', (scoreData['duration_accuracy'] as double) * 100),

          // Algorithm Scores
          if (scoreData.containsKey('individual_scores')) ...[
            const SizedBox(height: 8),
            Text(
              'Algorithm Scores:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: (scoreData['individual_scores'] as Map<String, dynamic>)
                  .entries
                  .map((entry) => _buildAlgorithmChip(context, entry.key, (entry.value as double? ?? 0.0) * 100))
                  .toList(),
            ),
          ],

          // Note Details
          if (noteDetailsList != null && noteDetailsList.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Note Details:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Column(
              children: noteDetailsList.map((noteData) {
                final note = noteData as Map<String, dynamic>;
                final targetNoteName = note['target_note_name'] ?? 'N/A';
                final playedNoteName = note['played_note_name'] ?? 'N/A';
                final isCorrectPitch = note['is_correct_pitch'] ?? false;
                final onsetErr = note['onset_error'] ?? 'N/A';
                final durationErr = note['duration_error'] ?? 'N/A';
                final noteIndex = noteDetailsList.indexOf(noteData);

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Note ${noteIndex + 1}: Target: $targetNoteName, Played: $playedNoteName',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Correct Pitch: ${isCorrectPitch ? "Yes" : "No"}',
                          style: TextStyle(
                            color: isCorrectPitch ? Colors.green : Colors.red,
                          ),
                        ),
                        Text('Onset Error: $onsetErr ms'),
                        Text('Duration Error: $durationErr ms'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Note: Removed Close button since dialogs should never auto-dismiss
          // and should be handled by parent dialog buttons
        ],
      ),
    );
  }

  /// Build a metric row with label, value, and optional progress indicator
  Widget _buildMetricRow(BuildContext context, String label, double value,
      {bool isMilliseconds = false, bool isScore = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            children: [
              Text(
                isMilliseconds ? '${value.toStringAsFixed(2)}ms' : '${value.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isScore ? _getColorForScore(value / 100) : Colors.black,
                ),
              ),
              if (isScore) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: value / 100,
                    backgroundColor: Colors.grey.shade300,
                    color: _getColorForScore(value / 100),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Build an algorithm score chip
  Widget _buildAlgorithmChip(BuildContext context, String algorithm, double percentValue) {
    // Format algorithm name to be more readable
    final readableName = algorithm
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
        .join(' ');

    // Add brief description for each algorithm
    String description = '';
    switch (algorithm) {
      case 'dtw':
        description = '(Timing)';
        break;
      case 'levenshtein':
        description = '(Notes)';
        break;
      case 'lcs':
        description = '(Patterns)';
        break;
      case 'cosine':
        description = '(Overall)';
        break;
      case 'exact_match':
        description = '(Exact)';
        break;
      default:
        description = '';
    }

    return Chip(
      label: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall,
          children: [
            TextSpan(
              text: '$readableName $description: ',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
            TextSpan(
              text: '${percentValue.toStringAsFixed(0)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getColorForScore(percentValue / 100),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.grey.shade200,
    );
  }

  /// Get color based on score (0.0 to 1.0)
  Color _getColorForScore(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }
}
