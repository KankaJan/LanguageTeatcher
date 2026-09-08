/// Learning state of a word after at least one lesson.
enum WordState { learning, known }

/// One recorded answer from the child: a production pass of a lesson.
///
/// [adultScore] is set when the parent grades it in the review inbox.
/// [autoScore] is set only when the speech recognizer was *confident*
/// (an unsure recognition leaves it null and stores just [transcript] and
/// [confidence] so the inbox can show the machine's uncertain guess).
/// The parent's grade always outranks the machine: see [effectiveScore].
class Attempt {
  Attempt({
    required this.id,
    required this.wordId,
    required this.lesson,
    required this.repetition,
    required this.filePath,
    required this.createdAt,
    this.adultScore,
    this.autoScore,
    this.confidence,
    this.transcript,
  });

  final int id;
  final String wordId;
  final int lesson;
  final int repetition;
  final String filePath;
  final DateTime createdAt;
  int? adultScore;
  int? autoScore;
  double? confidence;
  String? transcript;

  /// The score that counts: parent override first, confident auto second.
  int? get effectiveScore => adultScore ?? autoScore;

  /// Needs a human: no parent grade and no confident automatic one.
  bool get needsReview => effectiveScore == null;

  /// The recognizer ran but wasn't confident enough to score.
  bool get wasUnsure => autoScore == null && transcript != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'word_id': wordId,
        'lesson': lesson,
        'repetition': repetition,
        'file': filePath,
        'created_at': createdAt.toIso8601String(),
        'adult_score': adultScore,
        'auto_score': autoScore,
        'confidence': confidence,
        'transcript': transcript,
      };

  factory Attempt.fromJson(Map<String, dynamic> json) => Attempt(
        id: json['id'] as int,
        wordId: json['word_id'] as String,
        lesson: json['lesson'] as int,
        repetition: json['repetition'] as int,
        filePath: json['file'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        adultScore: json['adult_score'] as int?,
        autoScore: json['auto_score'] as int?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        transcript: json['transcript'] as String?,
      );
}

/// Where a word stands in the curriculum. Words never seen in a lesson have
/// no entry at all. [sourceLesson] is the lesson that produced this state, so
/// late grading of an older lesson cannot overwrite a newer outcome.
class WordProgress {
  const WordProgress({
    required this.state,
    required this.dueLesson,
    required this.sourceLesson,
    this.lastAvgScore,
  });

  final WordState state;
  final int dueLesson;
  final int sourceLesson;
  final double? lastAvgScore;

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'due_lesson': dueLesson,
        'source_lesson': sourceLesson,
        'last_avg_score': lastAvgScore,
      };

  factory WordProgress.fromJson(Map<String, dynamic> json) => WordProgress(
        state: WordState.values.byName(json['state'] as String),
        dueLesson: json['due_lesson'] as int,
        sourceLesson: json['source_lesson'] as int,
        lastAvgScore: (json['last_avg_score'] as num?)?.toDouble(),
      );
}
