//setup code begins
import 'dart:math';
import 'dart:io';

int Max_Num = 40;
List<List<String>> DOC = List.generate(Max_Num, (index) {
  if (index == 0) {
    return ['Generated String', 'User String', 'Result'];
  } else {
    return List.filled(3, '');
  }
}); //documentation setup - setting a Max_num rows table with 3 columns: generated string, users string, and the result
int DOC_index = 0;
//setup code ends

//function 1 - Generates a random 5 character string
String GenerateRandomString() {
  const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  var random = Random.secure();
  var values =
      List<String>.generate(5, (i) => chars[random.nextInt(chars.length)]);
  String current_str = values.join('');
  DOC_index++;
  DOC[DOC_index][0] = current_str; //inserting the generated string to the table
  return current_str;
}

//function 2 - Grading the users string  if the user's string is the same as the generated string
int GradeUserString(String user_str) {
  int grade = 0;
  if (user_str.length != 5) {
    return 0;
  }
  for (int i = 0; i < 5; i++) {
    String cur_char = user_str[i];
    if (cur_char == DOC[DOC_index][0][i]) {
      grade += 2; //the user gets 2 points for each correct character
    } else if (DOC[DOC_index][0].contains(cur_char)) {
      grade++; //the user gets 1 point for each correct character that is in the wrong place
    }
  }
  DOC[DOC_index][2] = grade.toString(); //inserting the grade to the table
  return grade;
}

//function 3 - Generates a game round
void GenerateGame() {
  String generated_str = GenerateRandomString();
  print('Generated String: $generated_str');
  print('Enter a 5 character string: ');
  String? user_str = stdin.readLineSync();
  if (user_str != null) {
    int grade = GradeUserString(user_str);
    print('Grade: $grade');
    print('Generated String: ${DOC[DOC_index][0]}');
    print('User String: $user_str');
    DOC[DOC_index][1] = user_str;
    DOC[DOC_index][2] = grade.toString();
    print('Result: ${DOC[DOC_index][2]}');
  } else {
    print('No input provided.');
  }
  print(DOC_index);
}

//function 4 - Main function that continues the game
void main() {
  while (true) {
    GenerateGame();
    print('Do you want to play again? (yes/no): ');
    String? answer = stdin.readLineSync();
    if (answer == null || answer.toLowerCase() != 'yes') {
      break;
    }
  }
  print('Game over. Thank you for playing!');
}
