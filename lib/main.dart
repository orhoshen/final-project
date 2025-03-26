import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Game Modes',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Game Mode'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ComputerModeGame(),
                  ),
                );
              },
              child: const Text('Play vs Computer'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlayerModeGame(),
                  ),
                );
              },
              child: const Text('Play vs Another Player'),
            ),
          ],
        ),
      ),
    );
  }
}

class ComputerModeGame extends StatefulWidget {
  const ComputerModeGame({super.key});

  @override
  _ComputerModeGameState createState() => _ComputerModeGameState();
}

class _ComputerModeGameState extends State<ComputerModeGame> {
  final int maxNum = 40;
  late List<List<String>> doc;
  int docIndex = 0;
  int totalScore = 0;
  String generatedString = '';
  String result = '';
  final TextEditingController userInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    doc = List.generate(maxNum, (index) {
      if (index == 0) {
        return ['Generated String', 'User String', 'Result'];
      } else {
        return List.filled(3, '');
      }
    });
  }

  String generateRandomString() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
    var random = Random.secure();
    var values = List<String>.generate(5, (i) => chars[random.nextInt(chars.length)]);
    String currentStr = values.join('');
    setState(() {
      docIndex++;
      doc[docIndex][0] = currentStr;
      generatedString = currentStr;
    });
    return currentStr;
  }

  int gradeUserString(String userStr) {
    int grade = 0;
    if (userStr.length != 5) {
      return 0;
    }
    for (int i = 0; i < 5; i++) {
      String curChar = userStr[i];
      if (curChar == doc[docIndex][0][i]) {
        grade += 2;
      } else if (doc[docIndex][0].contains(curChar)) {
        grade++;
      }
    }
    setState(() {
      totalScore += grade;
      doc[docIndex][2] = grade.toString();
    });
    return grade;
  }

  void generateGame() {
    String generatedStr = generateRandomString();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Your Turn'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Generated String: $generatedStr'),
              TextField(
                controller: userInputController,
                decoration: const InputDecoration(hintText: 'Enter a 5-character string'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                String userStr = userInputController.text;
                int grade = gradeUserString(userStr);
                setState(() {
                  doc[docIndex][1] = userStr;
                  result = 'Grade: $grade\nTotal Score: $totalScore\nGenerated String: $generatedStr\nUser String: $userStr';
                });
                Navigator.of(context).pop();
                askToPlayAgain();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void askToPlayAgain() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Play Again?'),
          content: Text('Your total score so far: $totalScore'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                generateGame();
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Thank You!'),
                      content: Text('Your final score is: $totalScore\nHave a nice day!'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Computer'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: generateGame,
              child: const Text('Start Game'),
            ),
            const SizedBox(height: 20),
            Text(
              result,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerModeGame extends StatefulWidget {
  const PlayerModeGame({super.key});

  @override
  _PlayerModeGameState createState() => _PlayerModeGameState();
}

class _PlayerModeGameState extends State<PlayerModeGame> {
  final int maxNum = 40;
  late List<List<String>> doc;
  int docIndex = 0;
  int totalScore = 0;
  String result = '';
  final TextEditingController generatedStringController = TextEditingController();
  final TextEditingController userInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    doc = List.generate(maxNum, (index) {
      if (index == 0) {
        return ['Generated String', 'User String', 'Result'];
      } else {
        return List.filled(3, '');
      }
    });
  }

  int gradeUserString(String userStr) {
    int grade = 0;
    if (userStr.length != 5) {
      return 0;
    }
    for (int i = 0; i < 5; i++) {
      String curChar = userStr[i];
      if (curChar == doc[docIndex][0][i]) {
        grade += 2;
      } else if (doc[docIndex][0].contains(curChar)) {
        grade++;
      }
    }
    setState(() {
      totalScore += grade;
      doc[docIndex][2] = grade.toString();
    });
    return grade;
  }

  void generateGame() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Player 1: Enter a String'),
          content: TextField(
            controller: generatedStringController,
            decoration: const InputDecoration(hintText: 'Enter a 5-character string'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String generatedStr = generatedStringController.text;
                if (generatedStr.length == 5) {
                  setState(() {
                    docIndex++;
                    doc[docIndex][0] = generatedStr;
                  });
                  Navigator.of(context).pop();
                  askPlayerToGuess();
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void askPlayerToGuess() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Player 2: Your Turn'),
          content: TextField(
            controller: userInputController,
            decoration: const InputDecoration(hintText: 'Enter a 5-character string'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                String userStr = userInputController.text;
                int grade = gradeUserString(userStr);
                setState(() {
                  doc[docIndex][1] = userStr;
                  result = 'Grade: $grade\nTotal Score: $totalScore\nGenerated String: ${doc[docIndex][0]}\nUser String: $userStr';
                });
                Navigator.of(context).pop();
                askToPlayAgain();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void askToPlayAgain() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Play Again?'),
          content: Text('Your total score so far: $totalScore'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                generateGame();
              },
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Thank You!'),
                      content: Text('Your final score is: $totalScore\nHave a nice day!'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Close'),
                        ),
                      ],
                    );
                  },
                );
              },
              child: const Text('No'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Play vs Another Player'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: generateGame,
              child: const Text('Start Game'),
            ),
            const SizedBox(height: 20),
            Text(
              result,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
