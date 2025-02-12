import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/question_model.dart';
import '../providers/question_state_provider.dart';

class QuestionCard extends ConsumerStatefulWidget {
  final QuestionModel question;
  final Function(int) onAnswer;

  const QuestionCard({
    Key? key,
    required this.question,
    required this.onAnswer,
  }) : super(key: key);

  @override
  ConsumerState<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends ConsumerState<QuestionCard> {
  Future<void> _handleAnswer(int index) async {
    final questionState = ref.read(questionStateProvider.notifier);
    if (questionState.hasAnswered(widget.question.id)) return; // Prevent multiple answers
    
    final isCorrect = index == widget.question.correctAnswer;
    questionState.recordAnswer(widget.question.id, index, isCorrect);
    widget.onAnswer(index);

    // Update Firestore with the user's answer
    try {
      await FirebaseFirestore.instance
          .collection('questions')
          .doc(widget.question.id)
          .update({
        'userAnswer': index,
        'userIsCorrect': isCorrect,
        'answeredAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[QuestionCard] Answer saved to Firestore');
    } catch (e) {
      debugPrint('[QuestionCard] Error saving answer to Firestore: $e');
    }
  }

  Color _getOptionColor(int index) {
    final answer = ref.watch(questionStateProvider)[widget.question.id];
    if (answer == null) {
      return Colors.white.withOpacity(0.1); // Default unselected state
    }

    final isSelected = answer.selectedAnswer == index;
    final isCorrect = widget.question.correctAnswer == index;

    if (isSelected && isCorrect) {
      return Colors.green.withOpacity(0.3); // Correct answer
    } else if (isSelected && !isCorrect) {
      return Colors.red.withOpacity(0.3); // Wrong answer
    } else if (isCorrect) {
      return Colors.green.withOpacity(0.3); // Show correct answer
    }

    return Colors.white.withOpacity(0.1); // Other options
  }

  @override
  Widget build(BuildContext context) {
    final answer = ref.watch(questionStateProvider)[widget.question.id];
    final hasAnswered = answer != null;

    return Container(
      color: Colors.grey[900],
      child: SafeArea(
        top: false,  // Don't apply SafeArea padding to top
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 48, // Space for FeedSelectionPill + its padding
              left: 8.0,
              right: 8.0,
              bottom: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question Header
                Card(
                  color: Colors.grey[850],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.quiz,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Question',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.question.questionText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Options
                ...List.generate(widget.question.options.length, (index) {
                  final isSelected = answer?.selectedAnswer == index;
                  final isCorrect = widget.question.correctAnswer == index;

                  return Card(
                    color: _getOptionColor(index),
                    margin: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: hasAnswered ? null : () => _handleAnswer(index),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          children: [
                            // Option letter (A, B, C, etc.)
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasAnswered && (isSelected ?? false || isCorrect)
                                    ? (isCorrect ? Colors.green : Colors.red)
                                    : Colors.white.withOpacity(0.2),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + index), // A, B, C, etc.
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: (isSelected ?? false) ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                widget.question.options[index],
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: (isSelected ?? false) ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (hasAnswered && ((isSelected ?? false) || isCorrect))
                              Icon(
                                isCorrect ? Icons.check_circle : Icons.cancel,
                                color: isCorrect ? Colors.green : Colors.red,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                // Explanation
                if (hasAnswered) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Colors.grey[850],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Explanation',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.question.explanation,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 