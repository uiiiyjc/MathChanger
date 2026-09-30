/// One line of working transcribed from an image of mathematics.
class MathStep {
  const MathStep({
    required this.index,
    required this.latex,
    this.explanation,
  });

  factory MathStep.fromJson(Map<String, dynamic> json) => MathStep(
        index: (json['index'] as num?)?.toInt() ?? 0,
        latex: (json['latex'] as String? ?? '').trim(),
        explanation: (json['explanation'] as String?)?.trim(),
      );

  final int index;
  final String latex;
  final String? explanation;

  Map<String, dynamic> toJson() => {
        'index': index,
        'latex': latex,
        'explanation': explanation,
      };
}

/// The full result of analysing a single image.
class RecognitionResult {
  const RecognitionResult({required this.steps, this.rawText});

  factory RecognitionResult.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final steps = rawSteps is List
        ? rawSteps
            .whereType<Map>()
            .map((e) => MathStep.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <MathStep>[];
    return RecognitionResult(steps: steps, rawText: json['rawText'] as String?);
  }

  final List<MathStep> steps;
  final String? rawText;

  bool get isEmpty => steps.isEmpty;

  /// Every step joined into one document, ready to paste into a paper.
  String get fullLatex => steps.map((s) => s.latex).join('\n\n');

  Map<String, dynamic> toJson() => {
        'steps': steps.map((s) => s.toJson()).toList(),
        'rawText': rawText,
      };
}
