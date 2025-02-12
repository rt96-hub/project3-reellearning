# Step-by-Step Outline for Adding In-Feed Questions

Below is an outline for how you can add the feature where, after a user has been on the home feed for about 2 minutes, a multiple choice question (generated via an LLM) is inserted into the video feed. This outline covers:
- When and how to trigger the question generation
- How to insert the question into the feed (mixing video and question items)
- How to render the question in the UI and collect user response
- How to track and store the question and the response in the database using Cloud Functions

---

## 1. Extend the Data Models

### a. Define a New Question Model

Create a new model (e.g., `QuestionModel`) that represents a multiple choice question. For an MVP, include fields like:
- unique ID
- the question text
- an array of options (with one being the correct answer)
- the correct answer (or index)
- a brief explanation

```
// question collection
questions: {
  questionId: {
    userId: Reference,
    data: {
      videoId: Array<Reference>,
      questionText: String,
      options: Array<string>,
      correctAnswer: number,
      explanation: string,
    }
    userAnswer: number,
    userIsCorrect: boolean,
    answeredAt: Timestamp,
    createdAt: Timestamp,
    updatedAt: Timestamp
  }
}
```

### b. Update the Feed Item Type

Since your feed is currently a list of video objects (`VideoModel`), you’ll want to transform it into a list that can contain both videos and questions. You can do this by:
- Creating an abstract class or union type (e.g., `FeedItem`)
- Having `VideoModel` and `QuestionModel` implement it
- Alternatively, attaching a type flag on each item (e.g., `{ type: 'video' }` vs. `{ type: 'question' }`)

For simplicity, you could update your provider to work with a `List<dynamic>` where you later check using `is QuestionModel`.

---

## 2. Use a Cloud Function to Generate Questions

### a. Create a Cloud Function Endpoint (`/get_question`)

This endpoint will:
- Accept context from the client (e.g., video IDs or aggregated metadata from the last 2 minutes)
- For an MVP, simply return a mocked question object (later replace with LLM integration)

```
# In your Firebase Cloud Functions (e.g., using Python or Node.js):

def get_question(req):
    # Parse the input – e.g., list of recent video IDs or context info
    context = req.get_json().get('context', {})
    
    # For MVP, prepare a simple question object.
    question = {
        "userId": /users/userId,
        "data": {
            "videoId": [/* list of recent video IDs */],
            "questionText": "Based on the last videos, what is the main concept you learned?",
            "options": ["Option A", "Option B", "Option C"],
            "correctAnswer": 1,
            "explanation": "Option A is correct because it relates to the core concept presented."
        },
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp()
    }
    
    # Store the question in Firestore (optional, for tracking)
    # [Implement Firestore write here if needed]

    return {
        "status": "success",
        "question": question.data
    }
```

### b. Deploy and Test the Function

Ensure your cloud function is deployed and test it with simple HTTP requests before integrating it into the app.

---

## 3. Trigger the Question Generation Event in the App

### a. Timer-Based Trigger

Within your `HomeScreen` (or a related provider), set up a timer that tracks cumulative watch time. For example, after 2 minutes you:
- Collect the context (e.g., last 2 minutes of video IDs or metadata)
- Call the `/get_question` endpoint

```
class HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? questionTimer;
  
  @override
  void initState() {
    super.initState();
    // Initialize the timer to trigger every 2 minutes (120 seconds)
    questionTimer = Timer.periodic(Duration(seconds: 120), (timer) {
      _triggerQuestionGeneration();
    });
  }

  void _triggerQuestionGeneration() async {
    // Collect IDs or context of the videos watched in the last 2 minutes.
    // For simplicity, you can send the current video’s context.
    final contextData = {
      "videoIds": [/* list of recent video IDs */]
      // add additional context if needed
    };

    // Call the cloud function endpoint
    final response = await http.post(
      Uri.parse("https://your-cloud-function-url/get_question"),
      body: json.encode({"context": contextData}),
      headers: {
        "Content-Type": "application/json",
      },
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      final questionData = result["question"];
      // Use your QuestionModel.fromMap constructor to create a question object
      final question = QuestionModel.fromMap(questionData, questionData["id"]);

      // Insert the question into the feed; for example, insert it 2 items ahead of the current index.
      _insertQuestionIntoFeed(question);
    }
  }

  void _insertQuestionIntoFeed(QuestionModel question) {
    // Read the current video feed from your paginatedVideoProvider
    final currentFeed = ref.read(paginatedVideoProvider.notifier);
    // Determine current video index
    final currentIndex = ref.read(currentVideoIndexProvider);
    // Insert the question item two videos ahead (or at a desired position)
    currentFeed.insertQuestionAt(currentIndex + 2, question);
  }

  @override
  void dispose() {
    questionTimer?.cancel();
    super.dispose();
  }
}
```

*Note:* You may need to modify the implementation of your `PaginatedVideoNotifier` (or create a new feed notifier) so that it can handle insertion of question objects into the list.

---

## 4. Render the Question in the Feed

### a. Update the PageView Builder

When building the feed in your `HomeScreen`, check the type of each item:
- If the item is a `VideoModel`, render the existing `VideoPlayerWidget`
- If the item is a `QuestionModel`, render a new `QuestionWidget`

```
Widget _buildFeedItem(dynamic item) {
  if (item is VideoModel) {
    return VideoPlayerWidget(
      video: item,
      // other properties…
    );
  } else if (item is QuestionModel) {
    return QuestionWidget(question: item);
  }
  return SizedBox.shrink();
}

// In the PageView.builder:
PageView.builder(
  controller: _pageController,
  scrollDirection: Axis.vertical,
  itemCount: feedItems.length,
  itemBuilder: (context, index) {
    return _buildFeedItem(feedItems[index]);
  },
);
```

### b. Create the Question Widget

The question widget should display:
- The question text
- The multiple choice options as buttons
- On tap, immediately reveal if the answer is correct or incorrect, along with the explanation

```
class QuestionWidget extends StatefulWidget {
  final QuestionModel question;

  const QuestionWidget({Key? key, required this.question}) : super(key: key);

  @override
  _QuestionWidgetState createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  int? selectedOptionIndex;
  bool answered = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.question.questionText,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            ...List.generate(widget.question.options.length, (index) {
              return ListTile(
                title: Text(widget.question.options[index]),
                leading: Radio<int>(
                  value: index,
                  groupValue: selectedOptionIndex,
                  onChanged: answered ? null : (value) {
                    setState(() {
                      selectedOptionIndex = value;
                    });
                  },
                ),
                onTap: answered ? null : () {
                  setState(() {
                    selectedOptionIndex = index;
                    answered = true;
                  });
                  // Store answer in Firestore and show immediate feedback.
                  _submitAnswer(index);
                },
              );
            }),
            if (answered)
              Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  selectedOptionIndex == widget.question.correctOptionIndex
                      ? "Correct! ${widget.question.explanation}"
                      : "Incorrect. ${widget.question.explanation}",
                  style: TextStyle(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _submitAnswer(int selectedIndex) {
    // Call your Firestore API or Cloud Function to store the user's response.
    // Example: Write to 'userQuestionResponses' collection with userId, questionId, selected option, timestamp.
  }
}
```

---

## 5. Track and Store the Generated Questions & User Responses

### a. Storing Questions
- When a question is generated (in the Cloud Function), write the question object to a collection (e.g., `questions`).
- Include metadata like the timestamp, the video context, etc.

### b. Tracking User Responses
- In the `QuestionWidget`’s answer submission method, update the question object with the user's answer
  - userAnswer: number
  - answeredAt: timestamp

```
Future<void> _submitAnswer(int selectedIndex) async {
  final questionId = widget.question.id
  final responseData = {
    'userAnswer': selectedIndex,
    'answeredAt': FieldValue.serverTimestamp(),
  };

  await FirebaseFirestore.instance.collection('questions').document(questionId).update(responseData);
}
```

---

## 6. Integration & Testing

1. **Integrate the Timer in HomeScreen:**  
   Verify that after 2 minutes (or the defined interval), the UI calls your cloud function and inserts a question into the feed.

2. **Feed Notifier Update:**  
   Adjust your `PaginatedVideoNotifier` (or create a new feed state notifier) to support inserting items that are not videos. Ensure your feed’s order is maintained.

3. **UI Testing:**  
   Test the new feed by scrolling through it. Validate that the question(s) appear at the correct time (e.g., 2 videos ahead of the current video) and that selecting an answer shows immediate feedback.

4. **Database Monitoring:**  
   Check that questions are stored and user responses are tracked in Firestore as expected.

5. **Iterate:**  
   Once the MVP is confirmed, you can replace the static question generation with integration to an LLM in your cloud function.

---

This outline should give you a concise yet thorough roadmap for developing and integrating the in-feed question feature into your TikTok-like app.