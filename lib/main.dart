import 'dart:convert'; // För JSON hantering
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sticky Notes',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        colorScheme:
            ColorScheme.fromSwatch().copyWith(secondary: Colors.orangeAccent),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.amber,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        textTheme: TextTheme(
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
        ),
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

  @override
  void initState() {
    super.initState();
    _loadNotes();
    searchController.addListener(_filterNotes);
  }

  // Ladda anteckningar från SharedPreferences
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

  // Spara anteckningar till SharedPreferences
  _saveNotes() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedNotes = notes.map((note) => json.encode(note)).toList();
    prefs.setStringList('notes', savedNotes);
  }

  // Lägg till en ny anteckning
  _addNote() async {
    Map<String, dynamic>? newNote = await showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController titleController = TextEditingController();
        TextEditingController contentController = TextEditingController();
        Color selectedColor = Colors.yellow;

        return AlertDialog(
          title: Text('Skapa en ny anteckning'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: InputDecoration(hintText: "Rubrik"),
              ),
              TextField(
                controller: contentController,
                decoration:
                    InputDecoration(hintText: "Skriv din anteckning här"),
                maxLines: 4,
              ),
              SizedBox(height: 10),
              Text('Välj färg:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _colorOption(Colors.yellow, selectedColor, () {
                    setState(() {
                      selectedColor = Colors.yellow;
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
              child: Text('Spara'),
            ),
          ],
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

  // Visa färgalternativ som knappar
  Widget _colorOption(Color color, Color selectedColor, Function() onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.all(5),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: selectedColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
      ),
    );
  }

  // Ta bort en anteckning
  _deleteNote(int index) {
    setState(() {
      notes.removeAt(index);
      filteredNotes.removeAt(index);
    });
    _saveNotes();
  }

  // Redigera en anteckning
  _editNote(int index) async {
    Map<String, dynamic>? editedNote = await showDialog(
      context: context,
      builder: (BuildContext context) {
        TextEditingController titleController =
            TextEditingController(text: notes[index]['title']);
        TextEditingController contentController =
            TextEditingController(text: notes[index]['content']);
        Color selectedColor = Color(notes[index]['color']);

        return AlertDialog(
          title: Text('Redigera anteckning'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: InputDecoration(hintText: "Rubrik"),
              ),
              TextField(
                controller: contentController,
                decoration:
                    InputDecoration(hintText: "Redigera din anteckning här"),
                maxLines: 4,
              ),
              SizedBox(height: 10),
              Text('Välj färg:'),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _colorOption(Colors.yellow, selectedColor, () {
                    setState(() {
                      selectedColor = Colors.yellow;
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
              child: Text('Spara'),
            ),
          ],
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

  // Filtrera anteckningar baserat på söktext
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

  // Beräkna kontrastfärg för soptunna
  Color _getTrashIconColor(Color noteColor) {
    double brightness = noteColor.computeLuminance();
    return brightness > 0.5 ? Colors.black : Colors.white;
  }

  // Visa snyggare instruktioner
  _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Instruktioner'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '1. Skapa en ny anteckning genom att trycka på +\n'
              '2. Välj en färg för din anteckning\n'
              '3. Sök efter anteckningar med sökfältet\n'
              '4. Redigera eller ta bort anteckningar genom att trycka på dem\n'
              '5. Anteckningarna sparas automatiskt lokalt på din enhet.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 10),
            Text(
              'Tryck på "Stäng" när du är klar.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Stäng'),
          ),
        ],
      ),
    );
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
        title: Text('Sticky Notes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Sök anteckningar...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredNotes.length,
              itemBuilder: (context, index) {
                Color noteColor = Color(filteredNotes[index]['color']);
                return Card(
                  color: noteColor,
                  margin: EdgeInsets.all(10),
                  child: ListTile(
                    leading:
                        Icon(FontAwesomeIcons.stickyNote, color: Colors.amber),
                    title: Text(
                      filteredNotes[index]['title']!,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(filteredNotes[index]['content']!),
                    onTap: () => _editNote(index),
                    trailing: IconButton(
                      icon: Icon(Icons.delete,
                          color: _getTrashIconColor(noteColor)),
                      onPressed: () => _deleteNote(index),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNote,
        child: Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _showInstructions,
                child: Row(
                  children: [
                    Icon(Icons.help_outline),
                    SizedBox(width: 5),
                    Text('Instruktioner'),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
