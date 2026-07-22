import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QuizRunnerDialog extends StatefulWidget {
  final int quizId;
  final String quizTitle;
  final bool isTrainerPreview;

  const QuizRunnerDialog({
    super.key,
    required this.quizId,
    required this.quizTitle,
    this.isTrainerPreview = false,
  });

  @override
  State<QuizRunnerDialog> createState() => _QuizRunnerDialogState();
}

class _QuizRunnerDialogState extends State<QuizRunnerDialog> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2/'));
  bool _isLoading = true;
  String? _error;
  List<dynamic> _questions = [];
  int _currentIndex = 0;
  final Map<int, int> _selectedAnswers = {}; // question_id -> option_id
  bool _isSubmitting = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _fetchQuizDetails();
  }

  Future<void> _fetchQuizDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await _dio.get(
        'quizzes/detail',
        queryParameters: {'quiz_id': widget.quizId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.data['success'] == true) {
        final quizData = response.data['quiz'];
        List<dynamic> questionsList = quizData['questions'] as List? ?? [];

        setState(() {
          _questions = questionsList;
          _isLoading = false;
          _error = questionsList.isEmpty ? 'This quiz does not contain any questions.' : null;
        });
      } else {
        throw StateError('Quiz details were not returned by the server.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load this quiz. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitQuiz() async {
    if (widget.isTrainerPreview) {
      setState(() {
        _result = {
          'score': _questions.length,
          'total': _questions.length,
          'percentage': 100.0,
          'passed': true,
          'xp_earned': 0,
          'message': 'Trainer Preview Complete! All questions tested.'
        };
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final answersPayload = <String, int>{};
      _selectedAnswers.forEach((qId, optId) {
        answersPayload[qId.toString()] = optId;
      });

      final response = await _dio.post(
        'quizzes/submit',
        data: {
          'quiz_id': widget.quizId,
          'answers': answersPayload,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _result = response.data;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is DioException
              ? (e.response?.data is Map ? e.response?.data['detail']?.toString() : null) ?? 'Quiz submission failed.'
              : 'Quiz submission failed.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 720,
        height: 580,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            if (widget.isTrainerPreview)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.remove_red_eye, color: Colors.purple),
                    SizedBox(width: 12),
                    Text(
                      'TRAINER PREVIEW MODE — answers are not submitted.',
                      style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : _result != null
                      ? _buildResultView()
                      : _buildQuizQuestionView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizQuestionView() {
    if (_questions.isEmpty) {
      return const Center(child: Text('No questions available in this quiz.'));
    }

    final currentQuestion = _questions[_currentIndex];
    final int qId = currentQuestion['id'];
    final List options = currentQuestion['options'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.quizTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Chip(
              label: Text('Question ${_currentIndex + 1} of ${_questions.length}'),
              backgroundColor: Colors.blue.shade50,
              labelStyle: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey.shade200,
          color: Colors.blue,
        ),
        const SizedBox(height: 24),

        // Question text
        Text(
          currentQuestion['text'] ?? '',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 20),

        // Options List
        Expanded(
          child: RadioGroup<int>(
            groupValue: _selectedAnswers[qId],
            onChanged: (value) {
              if (value != null) setState(() => _selectedAnswers[qId] = value);
            },
            child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              final int optId = opt['id'];
              final bool isSelected = _selectedAnswers[qId] == optId;

              return Card(
                elevation: isSelected ? 2 : 1,
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(opt['text'] ?? ''),
                  leading: Radio<int>(
                    value: optId,
                  ),
                  onTap: () {
                    setState(() {
                      _selectedAnswers[qId] = optId;
                    });
                  },
                ),
              );
            },
            ),
          ),
        ),

        // Bottom Controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton(
              onPressed: _currentIndex > 0
                  ? () {
                      setState(() {
                        _currentIndex--;
                      });
                    }
                  : null,
              child: const Text('Previous'),
            ),
            if (_currentIndex < _questions.length - 1)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentIndex++;
                  });
                },
                child: const Text('Next Question'),
              )
            else
              ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitQuiz,
                icon: const Icon(Icons.send),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultView() {
    final bool passed = _result!['passed'] == true;
    final int score = _result!['score'] ?? 0;
    final int total = _result!['total'] ?? 0;
    final double pct = double.parse((_result!['percentage'] ?? 0.0).toString());
    final int xp = _result!['xp_earned'] ?? 0;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            passed ? Icons.emoji_events : Icons.sentiment_dissatisfied,
            size: 72,
            color: passed ? Colors.amber : Colors.orange,
          ),
          const SizedBox(height: 12),
          Text(
            passed ? 'Congratulations!' : 'Keep Trying!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _result!['message'] ?? '',
            style: const TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: passed ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResultStat('Score', '$score / $total'),
                _buildResultStat('Percentage', '${pct.toStringAsFixed(1)}%'),
                _buildResultStat('XP Awarded', '+$xp XP'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Back to Dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
