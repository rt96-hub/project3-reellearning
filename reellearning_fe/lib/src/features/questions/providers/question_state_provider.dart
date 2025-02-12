import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuestionAnswer {
  final int selectedAnswer;
  final bool isCorrect;
  final DateTime answeredAt;

  QuestionAnswer({
    required this.selectedAnswer,
    required this.isCorrect,
    required this.answeredAt,
  });
}

class QuestionStateNotifier extends StateNotifier<Map<String, QuestionAnswer>> {
  QuestionStateNotifier() : super({});

  void recordAnswer(String questionId, int selectedAnswer, bool isCorrect) {
    state = {
      ...state,
      questionId: QuestionAnswer(
        selectedAnswer: selectedAnswer,
        isCorrect: isCorrect,
        answeredAt: DateTime.now(),
      ),
    };
  }

  QuestionAnswer? getAnswer(String questionId) {
    return state[questionId];
  }

  bool hasAnswered(String questionId) {
    return state.containsKey(questionId);
  }
}

final questionStateProvider = StateNotifierProvider<QuestionStateNotifier, Map<String, QuestionAnswer>>(
  (ref) => QuestionStateNotifier(),
);