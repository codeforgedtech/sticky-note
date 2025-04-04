import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'settings_page.dart';

void main() {
  runApp(Sticky());
}

class Sticky extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticky Notes',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        hintColor: Colors.deepOrangeAccent,
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.teal,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      home: NotesScreen(),
    );
  }
}

class NotesScreen extends StatefulWidget {
  @override
  _NotesScreenState createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Map<String, dynamic>> notes = [];
  List<Map<String, dynamic>> filteredNotes = [];
  TextEditingController searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    searchController.addListener(_filterNotes);
  }

  _loadNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedNotes = prefs.getStringList('notes');
    if (savedNotes != null) {
      setState(() {
        notes = savedNotes
            .map((note) => Map<String, dynamic>.from(json.decode(note)))
            .toList();
        filteredNotes = List.from(notes);
      });
    }
  }

  _saveNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedNotes = notes.map((note) => json.encode(note)).toList();
    prefs.setStringList('notes', savedNotes);
  }

  _addNote() async {
    Map<String, dynamic>? newNote = await showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController titleController = TextEditingController();
        TextEditingController contentController = TextEditingController();
        Color selectedColor = Colors.teal;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Create a new note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.teal,
                ),
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: "Title",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      hintText: "Write your note here",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Choose color:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _colorOption(Colors.teal, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.teal;
                        });
                      }),
                      _colorOption(Colors.green, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.green;
                        });
                      }),
                      _colorOption(Colors.blue, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.blue;
                        });
                      }),
                      _colorOption(Colors.pink, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.pink;
                        });
                      }),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'title': titleController.text,
                      'content': contentController.text,
                      'color': selectedColor.value,
                    });
                  },
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (newNote != null && newNote['title']!.isNotEmpty) {
      setState(() {
        notes.add(newNote);
        filteredNotes.add(newNote);
      });
      _saveNotes();
    }
  }

  _deleteNote(int index) {
    setState(() {
      notes.removeAt(index);
      filteredNotes.removeAt(index);
    });
    _saveNotes();
  }

  _editNote(int index) async {
    Map<String, dynamic>? editedNote = await showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController titleController =
            TextEditingController(text: notes[index]['title']);
        TextEditingController contentController =
            TextEditingController(text: notes[index]['content']);
        Color selectedColor = Color(notes[index]['color']);

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              title: Text(
                'Edit note',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.teal,
                ),
              ),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(height: 10),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      hintText: "Title",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(
                      hintText: "Edit your note here",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Choose color:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _colorOption(Colors.teal, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.teal;
                        });
                      }),
                      _colorOption(Colors.green, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.green;
                        });
                      }),
                      _colorOption(Colors.blue, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.blue;
                        });
                      }),
                      _colorOption(Colors.pink, selectedColor, () {
                        setState(() {
                          selectedColor = Colors.pink;
                        });
                      }),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop({
                      'title': titleController.text,
                      'content': contentController.text,
                      'color': selectedColor.value,
                    });
                  },
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (editedNote != null && editedNote['title']!.isNotEmpty) {
      setState(() {
        notes[index] = editedNote;
        filteredNotes[index] = editedNote;
      });
      _saveNotes();
    }
  }

  _filterNotes() {
    setState(() {
      filteredNotes = notes
          .where((note) =>
              note['title']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()) ||
              note['content']!
                  .toLowerCase()
                  .contains(searchController.text.toLowerCase()))
          .toList();
    });
  }

  _syncToDatabase() {
    // Lägg här din kod för att spara noterna till en databas
    print("Syncing notes to the database...");
    // Du kan anropa en API eller en lokal databas här.
  }

  @override
  void dispose() {
    searchController.removeListener(_filterNotes);
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(
            'Sticky Notes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.teal,
          elevation: 4,
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  labelText: 'Search notes...',
                  prefixIcon: Icon(Icons.search, color: Colors.teal),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                  itemCount: filteredNotes.length,
                  itemBuilder: (context, index) {
                    Color noteColor = Color(filteredNotes[index]['color']);
                    return GestureDetector(
                        onTap: () async {
                          // Öppna redigeringsdialogen när man trycker på en anteckning
                          await _editNote(index);
                        },
                        child: Card(
                          color: noteColor,
                          margin:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.4),
                                width: 1.5),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(filteredNotes[index]['title'],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18)),
                                      SizedBox(height: 8),
                                      Text(filteredNotes[index]['content'],
                                          style: TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.white),
                                  onPressed: () {
                                    _deleteNote(index);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ));
                  }),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });

            if (index == 0) {
              _addNote();
            } else if (index == 1) {
              _showUserDialog(context);
            } else if (index == 2) {
              _syncToDatabase();
            }
            if (index == 3) {
              _showInstructions();
            }
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.plus,
                size: 30, // Större ikon för bättre användarupplevelse
              ),
              label: 'Add',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                FontAwesomeIcons.user,
                size: 30,
              ),
              label: 'User',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.sync,
                size: 30,
              ),
              label: 'Sync',
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.help_outline, // Hjälpikon längst ner
                size: 30,
              ),
              label: 'Help',
            ),
          ],
          selectedItemColor: Colors.teal, // Färg för vald item
          unselectedItemColor: Colors.grey, // Färg för icke-valda item
          backgroundColor:
              Colors.white, // Bakgrundsfärg för BottomNavigationBar
          type: BottomNavigationBarType
              .fixed, // Förhindrar att items ändrar sig när du skrollar
          elevation: 5, // Lägger till en lätt skugga för en mer modern look
        ));
  }

  Widget _colorOption(Color color, Color currentColor, Function onTap) {
    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        margin: EdgeInsets.only(right: 10),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            width: 2,
            color: currentColor == color ? Colors.black : Colors.transparent,
          ),
        ),
      ),
    );
  }

  _showInstructions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Instructions'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Sticky Notes App!\n\n',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'How to use the app:\n'
                  '1. To create a new note, click the "+" icon at the bottom of the screen.\n'
                  '2. Enter a title and content for your note. You can also choose a color for your note.\n'
                  '3. Your note will be saved locally on your device and will appear in the main screen.\n\n'
                  'Search Notes:\n'
                  'You can search for your notes by typing keywords in the search bar at the top of the screen.\n\n'
                  'Delete or Edit Notes:\n'
                  'To delete a note, click the trash icon on the note card.\n'
                  'To edit a note, tap the note and update the title, content, or color.\n\n'
                  'Sync to Database:\n'
                  'To sync your notes to the cloud, tap the "Sync" icon in the bottom navigation bar. \n'
                  'Note: You must be logged in to sync notes to the database.\n\n'
                  'Enjoy using Sticky Notes!',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

_showUserDialog(BuildContext context) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  String userName = prefs.getString('username') ?? 'User';

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isLoggedIn ? Icons.account_circle : Icons.login,
                size: 60,
                color: isLoggedIn ? Colors.teal : Colors.grey,
              ),
              SizedBox(height: 10),
              Text(
                isLoggedIn ? 'Welcome, $userName!' : 'Log in',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                isLoggedIn
                    ? 'You are logged in as $userName.'
                    : 'To sync your notes, please log in first.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (isLoggedIn) {
                    prefs.setBool('isLoggedIn', false);
                    Navigator.of(context).pop();
                  } else {
                    Navigator.of(context).pop();
                    _navigateToLoginPage(context);
                  }
                },
                child: Text(isLoggedIn ? 'Log out' : 'Log in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isLoggedIn ? Colors.redAccent : Colors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Close', style: TextStyle(color: Colors.black54)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

_navigateToLoginPage(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LoginPage(
        onClose: () => Navigator.of(context).pop(),
      ),
    ),
  );
}

class LoginPage extends StatefulWidget {
  final VoidCallback onClose;

  LoginPage({required this.onClose});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true; // Håller reda på om vi är på login eller register

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.black.withOpacity(0.5), // Halvtransparent bakgrund
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: isLogin ? _buildLogin() : _buildRegister(),
          ),
        ),
      ),
    );
  }

  Widget _buildLogin() {
    return _buildAuthForm(
      title: "Login",
      buttonText: "Login",
      bottomText: "Don't have an account? Register",
      onButtonPressed: () {
        // Hantera login
      },
      onBottomTextPressed: () {
        setState(() {
          isLogin = false;
        });
      },
    );
  }

  Widget _buildRegister() {
    return _buildAuthForm(
      title: "Register",
      buttonText: "Sign Up",
      bottomText: "Already have an account? Login",
      onButtonPressed: () {
        // Hantera register
      },
      onBottomTextPressed: () {
        setState(() {
          isLogin = true;
        });
      },
    );
  }

  Widget _buildAuthForm({
    required String title,
    required String buttonText,
    required String bottomText,
    required VoidCallback onButtonPressed,
    required VoidCallback onBottomTextPressed,
  }) {
    return Card(
      key: ValueKey(title),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 5,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.grey),
                  onPressed: widget.onClose, // Stänger login/register
                ),
              ],
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email, color: Colors.teal),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock, color: Colors.teal),
              ),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onButtonPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(buttonText,
                  style: TextStyle(fontSize: 16, color: Colors.white)),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: onBottomTextPressed,
              child: Text(
                bottomText,
                style: TextStyle(color: Colors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
