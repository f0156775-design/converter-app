import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Converter',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF6F2FF),
      ),
      home: const SimpleConverter(),
    );
  }
}

class Unit {
  final String name;
  final double toBase;
  const Unit(this.name, this.toBase);
}

class Category {
  final String name;
  final String emoji;
  final Color color;
  final List<Unit> units;
  final bool isTemp;
  const Category(this.name, this.emoji, this.color, this.units, {this.isTemp = false});
}

class SimpleConverter extends StatefulWidget {
  const SimpleConverter({super.key});
  @override
  State<SimpleConverter> createState() => _SimpleConverterState();
}

class _SimpleConverterState extends State<SimpleConverter> {
  List<Category> categories = [
    Category('Age', '🎂', Colors.pink, [
      Unit('Years', 31556952), Unit('Months', 2629746), Unit('Weeks', 604800),
      Unit('Days', 86400), Unit('Hours', 3600), Unit('Minutes', 60), Unit('Seconds', 1),
    ]),
    Category('Length', '📏', Colors.blue, [
      Unit('Kilometer', 1000), Unit('Meter', 1), Unit('Centimeter', 0.01),
      Unit('Millimeter', 0.001), Unit('Mile', 1609.34), Unit('Foot', 0.3048), Unit('Inch', 0.0254),
    ]),
    Category('Weight', '⚖️', Colors.orange, [
      Unit('Kilogram', 1), Unit('Gram', 0.001), Unit('Milligram', 0.000001),
      Unit('Pound', 0.453592), Unit('Ounce', 0.0283495), Unit('Ton', 1000),
    ]),
    Category('Temperature', '🌡️', Colors.red, [
      Unit('Celsius', 1), Unit('Fahrenheit', 1), Unit('Kelvin', 1),
    ], isTemp: true),
    Category('Area', '📐', Colors.green, [
      Unit('Sq. Meter', 1), Unit('Sq. Kilometer', 1000000), Unit('Hectare', 10000),
      Unit('Acre', 4046.86), Unit('Sq. Foot', 0.092903),
    ]),
    Category('Volume', '💧', Colors.cyan, [
      Unit('Liter', 1), Unit('Milliliter', 0.001), Unit('Cubic Meter', 1000),
      Unit('Gallon', 3.78541), Unit('Cup', 0.236588),
    ]),
    Category('Time', '⏰', Colors.purple, [
      Unit('Second', 1), Unit('Minute', 60), Unit('Hour', 3600),
      Unit('Day', 86400), Unit('Week', 604800), Unit('Year', 31556952),
    ]),
    Category('Speed', '🚀', Colors.teal, [
      Unit('m / sec', 1), Unit('km / hour', 0.277778), Unit('mile / hour', 0.44704), Unit('Knot', 0.514444),
    ]),
    Category('Data', '💾', Colors.indigo, [
      Unit('Byte', 1), Unit('KB', 1024), Unit('MB', 1048576),
      Unit('GB', 1073741824), Unit('TB', 1099511627776),
    ]),
    Category('Energy', '⚡', Colors.amber, [
      Unit('Joule', 1), Unit('Calorie', 4.184), Unit('Kilocalorie', 4184), Unit('kWh', 3600000),
    ]),
  ];

  int selected = -1;
  String? fromUnit;
  String? toUnit;
  final fromCtrl = TextEditingController();
  String result = '';

  List<Map<String, dynamic>> history = [];
  List<String> addedCategoriesHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    String? h = prefs.getString('history');
    String? a = prefs.getString('added_categories');
    String? c = prefs.getString('saved_categories');
    if (h != null) {
      setState(() { history = List<Map<String, dynamic>>.from(jsonDecode(h)); });
    }
    if (a != null) {
      setState(() { addedCategoriesHistory = List<String>.from(jsonDecode(a)); });
    }
    // NEW: App band kar ke dobara kholo to categories bhi wapis aa jayengi
    if (c != null) {
      try {
        List<dynamic> decoded = jsonDecode(c);
        List<Category> loaded = decoded.map((e) {
          List<Unit> units = (e['units'] as List).map((u) => Unit(u['name'].toString(), (u['toBase'] as num).toDouble())).toList();
          return Category(
            e['name'].toString(),
            e['emoji'].toString(),
            Color((e['color'] as num).toInt()),
            units,
            isTemp: e['isTemp'] == true,
          );
        }).toList();
        if (loaded.isNotEmpty) {
          setState(() { categories = loaded; });
        }
      } catch (_) {}
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history', jsonEncode(history));
    await prefs.setString('added_categories', jsonEncode(addedCategoriesHistory));
  }

  // NEW: Categories ko save karne wala function
  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> data = categories.map((cat) {
      return {
        'name': cat.name,
        'emoji': cat.emoji,
        'color': cat.color.value,
        'isTemp': cat.isTemp,
        'units': cat.units.map((u) => {'name': u.name, 'toBase': u.toBase}).toList(),
      };
    }).toList();
    await prefs.setString('saved_categories', jsonEncode(data));
  }

  void _addToHistory() {
    if (selected == -1 || fromUnit == null || toUnit == null || fromCtrl.text.isEmpty || result.isEmpty) return;
    String key = '${categories[selected].name}|${fromCtrl.text}|$fromUnit|$toUnit';
    history.removeWhere((e) => e['key'] == key);
    history.insert(0, {
      'key': key,
      'type': 'convert',
      'category': categories[selected].name,
      'emoji': categories[selected].emoji,
      'fromValue': fromCtrl.text,
      'fromUnit': fromUnit,
      'toUnit': toUnit,
      'result': result,
      'time': DateTime.now().toString().substring(0, 16),
    });
    if (history.length > 50) history = history.sublist(0, 50);
    _saveHistory();
    setState(() {});
  }

  void _addCategoryToHistory(String name, String emoji) {
    addedCategoriesHistory.remove(name);
    addedCategoriesHistory.insert(0, name);
    history.insert(0, {
      'key': 'added_${name}_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'added',
      'category': name,
      'emoji': emoji,
      'fromValue': '',
      'fromUnit': 'New Category Added',
      'toUnit': '',
      'result': '',
      'time': DateTime.now().toString().substring(0, 16),
    });
    _saveHistory();
    _saveCategories();
    setState(() {});
  }

  void _selectCategory(int i) {
    setState(() { selected = i; fromUnit = null; toUnit = null; fromCtrl.text = ''; result = ''; });
  }

  void _clearAll() {
    setState(() { selected = -1; fromUnit = null; toUnit = null; fromCtrl.text = ''; result = ''; });
  }

  void _convert() {
    if (selected == -1 || fromUnit == null || toUnit == null) return;
    if (fromCtrl.text.isEmpty) { setState(() => result = ''); return; }
    double v = double.tryParse(fromCtrl.text) ?? 0;
    var cat = categories[selected];
    var from = cat.units.firstWhere((e) => e.name == fromUnit);
    var to = cat.units.firstWhere((e) => e.name == toUnit);
    double res;
    if (cat.isTemp) {
      double c = 0;
      if (from.name == 'Celsius') c = v;
      if (from.name == 'Fahrenheit') c = (v - 32) * 5 / 9;
      if (from.name == 'Kelvin') c = v - 273.15;
      if (to.name == 'Celsius') res = c;
      else if (to.name == 'Fahrenheit') res = c * 9 / 5 + 32;
      else res = c + 273.15;
    } else {
      res = v * from.toBase / to.toBase;
    }
    setState(() { result = res.toStringAsFixed(res.truncateToDouble() == res ? 0 : 2); });
    _addToHistory();
  }

  String _emojiForCategory(String name) {
    String n = name.toLowerCase().trim();
    if (n.contains('curren') || n.contains('money') || n.contains('paisa') || n.contains('rupee') || n.contains('dollar')) return '💰';
    if (n.contains('weight') || n.contains('wazan')) return '⚖️';
    if (n.contains('length') || n.contains('lambai')) return '📏';
    if (n.contains('temp')) return '🌡️';
    if (n.contains('age') || n.contains('umar')) return '🎂';
    if (n.contains('area')) return '📐';
    if (n.contains('volume') || n.contains('liquid') || n.contains('pani')) return '💧';
    if (n.contains('time') || n.contains('waqt')) return '⏰';
    if (n.contains('speed') || n.contains('raftar')) return '🚀';
    if (n.contains('data')) return '💾';
    if (n.contains('energy') || n.contains('bijli')) return '⚡';
    if (n.contains('fuel') || n.contains('fule') || n.contains('ful') || n.contains('petrol') || n.contains('diesel') || n.contains('cng') || n.contains('gas')) return '⛽';
    if (n.contains('shoe') || n.contains('juta') || n.contains('sandal')) return '👟';
    if (n.contains('cloth') || n.contains('kapra') || n.contains('shirt') || n.contains('dress')) return '👕';
    if (n.contains('food') || n.contains('khana') || n.contains('calorie') || n.contains('diet')) return '🍔';
    if (n.contains('gold') || n.contains('sona')) return '🥇';
    if (n.contains('land') || n.contains('zameen') || n.contains('plot') || n.contains('marla')) return '🏡';
    if (n.contains('cook') || n.contains('recipe')) return '🍳';
    if (n.contains('health') || n.contains('sehat') || n.contains('bmi')) return '❤️';
    if (n.contains('study') || n.contains('school') || n.contains('marks') || n.contains('grade')) return '📚';
    if (n.contains('sport') || n.contains('cricket') || n.contains('football')) return '🏏';
    if (n.contains('music') || n.contains('song')) return '🎵';
    return '✨';
  }

  Color _colorForCategory(String name) {
    String n = name.toLowerCase();
    if (n.contains('curren') || n.contains('money')) return Colors.green;
    if (n.contains('fuel') || n.contains('fule') || n.contains('petrol')) return Colors.orange;
    if (n.contains('food')) return Colors.red;
    if (n.contains('shoe')) return Colors.brown;
    if (n.contains('cloth')) return Colors.pink;
    if (n.contains('gold')) return Colors.amber;
    if (n.contains('health')) return Colors.redAccent;
    return Colors.deepPurple;
  }

  bool _isDuplicateCategory(String name) {
    String n = name.trim().toLowerCase();
    return categories.any((c) => c.name.trim().toLowerCase() == n);
  }

  void _showDuplicateMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Already existing this category'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }

  List<Unit> _suggestedUnitsFor(String name) {
    String n = name.toLowerCase().trim();
    if (n.isEmpty) return [];
    if (n.contains('curren') || n.contains('money') || n.contains('paisa')) {
      return [
        Unit('PKR - Pakistan', 1), Unit('USD - Dollar', 280), Unit('EUR - Euro', 305),
        Unit('GBP - Pound', 355), Unit('INR - Indian Rupee', 3.35), Unit('AED - Dirham', 76.2),
        Unit('SAR - Riyal', 74.6), Unit('CAD - Canadian Dollar', 205), Unit('AUD - Australian Dollar', 185),
        Unit('CNY - Yuan', 39), Unit('JPY - Yen', 1.85), Unit('KWD - Kuwaiti Dinar', 910),
      ];
    }
    if (n.contains('fuel') || n.contains('fule') || n.contains('ful') || n.contains('petrol') || n.contains('diesel')) {
      return [Unit('Liter', 1), Unit('Gallon', 3.78541), Unit('Milliliter', 0.001), Unit('PKR per Liter', 1), Unit('PKR per Gallon', 3.78541)];
    }
    if (n.contains('shoe') || n.contains('juta')) {
      return [Unit('UK Size', 2.54), Unit('US Size', 2.54), Unit('EU Size', 1.693), Unit('CM', 1)];
    }
    if (n.contains('cloth') || n.contains('kapra')) {
      return [Unit('Meter', 1), Unit('Yard', 0.9144), Unit('Foot', 0.3048), Unit('Inch', 0.0254)];
    }
    if (n.contains('food') || n.contains('calorie') || n.contains('diet')) {
      return [Unit('Calorie', 1), Unit('Kilocalorie', 1000), Unit('Joule', 0.239), Unit('Gram Protein', 1)];
    }
    if (n.contains('gold') || n.contains('sona')) {
      return [Unit('Tola', 11.66), Unit('Gram', 1), Unit('Ounce', 28.3495), Unit('Kilogram', 1000)];
    }
    if (n.contains('land') || n.contains('zameen') || n.contains('plot') || n.contains('marla')) {
      return [Unit('Marla', 25.29), Unit('Kanal', 505.857), Unit('Sq. Foot', 0.092903), Unit('Sq. Meter', 1), Unit('Acre', 4046.86)];
    }
    if (n.contains('cook') || n.contains('recipe')) {
      return [Unit('Cup', 0.236588), Unit('Tablespoon', 0.0147868), Unit('Teaspoon', 0.00492892), Unit('Gram', 0.001), Unit('Milliliter', 0.001)];
    }
    if (n.contains('health') || n.contains('bmi') || n.contains('sehat')) {
      return [Unit('Kilogram', 1), Unit('Pound', 0.453592), Unit('CM', 1), Unit('Inch', 2.54), Unit('Foot', 30.48)];
    }
    if (n.contains('study') || n.contains('marks') || n.contains('grade')) {
      return [Unit('Marks', 1), Unit('Percentage %', 1), Unit('GPA', 25), Unit('CGPA', 25)];
    }
    if (n.contains('sport') || n.contains('cricket')) {
      return [Unit('Runs', 1), Unit('Overs', 6), Unit('Wickets', 1), Unit('Balls', 1)];
    }
    if (n.contains('music')) {
      return [Unit('Minutes', 1), Unit('Seconds', 0.0166), Unit('Hours', 60)];
    }
    if (n.contains('length')) {
      return [Unit('Kilometer', 1000), Unit('Meter', 1), Unit('Centimeter', 0.01), Unit('Millimeter', 0.001), Unit('Mile', 1609.34), Unit('Foot', 0.3048), Unit('Inch', 0.0254)];
    }
    if (n.contains('weight')) {
      return [Unit('Kilogram', 1), Unit('Gram', 0.001), Unit('Pound', 0.453592), Unit('Ounce', 0.0283495), Unit('Ton', 1000)];
    }
    if (n.contains('time')) {
      return [Unit('Second', 1), Unit('Minute', 60), Unit('Hour', 3600), Unit('Day', 86400), Unit('Week', 604800)];
    }
    if (n.contains('temp')) {
      return [Unit('Celsius', 1), Unit('Fahrenheit', 1), Unit('Kelvin', 1)];
    }
    if (n.contains('age')) {
      return [Unit('Years', 31556952), Unit('Months', 2629746), Unit('Weeks', 604800), Unit('Days', 86400), Unit('Hours', 3600), Unit('Minutes', 60), Unit('Seconds', 1)];
    }
    if (n.contains('area')) {
      return [Unit('Sq. Meter', 1), Unit('Sq. Kilometer', 1000000), Unit('Hectare', 10000), Unit('Acre', 4046.86), Unit('Sq. Foot', 0.092903)];
    }
    if (n.contains('volume') || n.contains('liquid') || n.contains('pani')) {
      return [Unit('Liter', 1), Unit('Milliliter', 0.001), Unit('Cubic Meter', 1000), Unit('Gallon', 3.78541), Unit('Cup', 0.236588)];
    }
    if (n.contains('speed')) {
      return [Unit('m / sec', 1), Unit('km / hour', 0.277778), Unit('mile / hour', 0.44704), Unit('Knot', 0.514444)];
    }
    if (n.contains('data')) {
      return [Unit('Byte', 1), Unit('KB', 1024), Unit('MB', 1048576), Unit('GB', 1073741824), Unit('TB', 1099511627776)];
    }
    if (n.contains('energy')) {
      return [Unit('Joule', 1), Unit('Calorie', 4.184), Unit('Kilocalorie', 4184), Unit('kWh', 3600000)];
    }
    if (n.contains('pressure')) {
      return [Unit('Pascal', 1), Unit('Bar', 100000), Unit('PSI', 6894.76), Unit('ATM', 101325)];
    }
    if (n.contains('power')) {
      return [Unit('Watt', 1), Unit('Kilowatt', 1000), Unit('Horsepower', 745.7)];
    }
    String cap = name.trim().isEmpty ? 'Unit' : name.trim()[0].toUpperCase() + name.trim().substring(1);
    return [
      Unit('$cap - Main Unit', 1),
      Unit('$cap - Small Unit', 0.01),
      Unit('$cap - Large Unit', 100),
      Unit('$cap - Extra Unit', 1000),
    ];
  }

  List<Unit> _normalizeManualUnits(List<String> names, List<double> values) {
    if (names.isEmpty) return [];
    double firstVal = values[0] == 0 ? 1 : values[0];
    List<Unit> out = [];
    for (int i = 0; i < names.length; i++) {
      double v = values[i] == 0 ? 1 : values[i];
      double toBase = firstVal / v;
      if (i == 0) toBase = 1;
      out.add(Unit(names[i], toBase));
    }
    return out;
  }

  void _showAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    String selectedEmoji = '✨';
    List<TextEditingController> unitNameCtrls = [TextEditingController(), TextEditingController()];
    List<TextEditingController> unitValueCtrls = [TextEditingController(), TextEditingController()];
    List<String> emojiOptions = ['✨','💰','⛽','👟','👕','🍔','🥇','🏡','🍳','❤️','📚','🏏','🎵','📏','⚖️','🌡️','🎂','💧','⏰','🚀','💾','⚡'];
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<Unit> suggested = _suggestedUnitsFor(nameCtrl.text);
            return AlertDialog(
              title: const Text('Add New Category'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Category Name e.g. Fuel, Food, Shoe', border: OutlineInputBorder()),
                      onChanged: (_) {
                        selectedEmoji = _emojiForCategory(nameCtrl.text);
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: emojiOptions.map((e) {
                        bool isSel = e == selectedEmoji;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedEmoji = e),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: isSel ? Colors.deepPurple.withOpacity(0.2) : Colors.grey.shade100, border: Border.all(color: isSel ? Colors.deepPurple : Colors.grey.shade300, width: isSel ? 2 : 1)),
                            child: Center(child: Text(e, style: const TextStyle(fontSize: 20))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    if (suggested.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_isDuplicateCategory(nameCtrl.text)) {
                              Navigator.pop(context);
                              _showDuplicateMessage();
                              return;
                            }
                            setState(() { categories.add(Category(nameCtrl.text.trim(), selectedEmoji, _colorForCategory(nameCtrl.text), suggested)); });
                            _addCategoryToHistory(nameCtrl.text.trim(), selectedEmoji);
                            Navigator.pop(context);
                          },
                          icon: Text(selectedEmoji, style: const TextStyle(fontSize: 18)),
                          label: Text('Add All ${nameCtrl.text} Units (${suggested.length})'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                        ),
                      ),
                    if (suggested.isNotEmpty) const SizedBox(height: 4),
                    if (suggested.isNotEmpty)
                      Text('Suggested: ${suggested.map((e) => e.name).join(', ')}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(height: 10),
                    const Align(alignment: Alignment.centerLeft, child: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    const SizedBox(height: 8),
                    ...List.generate(unitNameCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(child: TextField(controller: unitNameCtrls[i], decoration: InputDecoration(labelText: 'Unit ${i + 1}', border: const OutlineInputBorder(), contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
                          const SizedBox(width: 6),
                          SizedBox(width: 70, child: TextField(controller: unitValueCtrls[i], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)))),
                        ]),
                      );
                    }),
                    TextButton.icon(onPressed: () { setDialogState(() { unitNameCtrls.add(TextEditingController()); unitValueCtrls.add(TextEditingController()); }); }, icon: const Icon(Icons.add), label: const Text('Add More Unit')),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    if (_isDuplicateCategory(nameCtrl.text)) {
                      Navigator.pop(context);
                      _showDuplicateMessage();
                      return;
                    }
                    List<String> names = [];
                    List<double> values = [];
                    for (int i = 0; i < unitNameCtrls.length; i++) {
                      if (unitNameCtrls[i].text.isNotEmpty) {
                        names.add(unitNameCtrls[i].text.trim());
                        values.add(double.tryParse(unitValueCtrls[i].text) ?? 1);
                      }
                    }
                    List<Unit> units = [];
                    if (names.length >= 2) {
                      units = _normalizeManualUnits(names, values);
                    } else {
                      if (suggested.isNotEmpty) units = suggested;
                      else return;
                    }
                    setState(() { categories.add(Category(nameCtrl.text.trim(), selectedEmoji, _colorForCategory(nameCtrl.text), units)); });
                    _addCategoryToHistory(nameCtrl.text.trim(), selectedEmoji);
                    Navigator.pop(context);
                  },
                  child: const Text('Add Category'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHistoryPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Row(children: [
                        if (history.isNotEmpty)
                          TextButton.icon(
                            onPressed: () {
                              setState(() { history.clear(); });
                              setSheetState(() {});
                              _saveHistory();
                            },
                            icon: const Icon(Icons.delete_forever, color: Colors.red, size: 18),
                            label: const Text('Clear All', style: TextStyle(color: Colors.red)),
                          ),
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: history.isEmpty
                        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🕒', style: TextStyle(fontSize: 50)), SizedBox(height: 10), Text('No history yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), ]))
                        : ListView.builder(
                            itemCount: history.length,
                            itemBuilder: (context, i) {
                              var h = history[i];
                              bool isAdded = h['type'] == 'added';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: CircleAvatar(backgroundColor: Colors.deepPurple.withOpacity(0.1), child: Text(h['emoji'] ?? '✨', style: const TextStyle(fontSize: 20))),
                                  title: Text(isAdded ? 'Added: ${h['category']}' : '${h['fromValue']} ${h['fromUnit']} = ${h['result']} ${h['toUnit']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: Text('${h['category']}  •  ${h['time']}', style: const TextStyle(fontSize: 12)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.deepPurple, size: 20),
                                        onPressed: () {
                                          if (isAdded) {
                                            _editAddedCategory(h, setSheetState);
                                          } else {
                                            Navigator.pop(context);
                                            int idx = categories.indexWhere((c) => c.name == h['category']);
                                            if (idx != -1) {
                                              setState(() {
                                                selected = idx;
                                                fromUnit = h['fromUnit'];
                                                toUnit = h['toUnit'];
                                                fromCtrl.text = h['fromValue'].toString();
                                                result = h['result'].toString();
                                              });
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                        onPressed: () {
                                          setState(() { history.removeAt(i); });
                                          setSheetState(() {});
                                          _saveHistory();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // EDIT - Sirf 3 boxes, naam edit nahi hoga, upar naam nahi aayega
  void _editAddedCategory(Map<String, dynamic> h, Function setSheetState) {
    String categoryName = h['category'].toString();
    int idx = categories.indexWhere((c) => c.name == categoryName);

    String oldFrom = '';
    String oldTo = '';
    String oldValue = '1';
    if (idx != -1 && categories[idx].units.isNotEmpty) {
      oldFrom = categories[idx].units[0].name;
      if (categories[idx].units.length > 1) {
        oldTo = categories[idx].units[1].name;
        oldValue = categories[idx].units[1].toBase.toString();
      }
    }

    final fromCtrl = TextEditingController(text: oldFrom);
    final toCtrl = TextEditingController(text: oldTo);
    final valueCtrl = TextEditingController(text: oldValue);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: fromCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Convert From',
                    hintText: 'e.g. PKR',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: toCtrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Convert To',
                    hintText: 'e.g. USD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Value',
                    hintText: 'e.g. 280',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (fromCtrl.text.trim().isEmpty || toCtrl.text.trim().isEmpty) return;
                setState(() {
                  if (idx != -1) {
                    var old = categories[idx];
                    double v = double.tryParse(valueCtrl.text) ?? 1;
                    if (v == 0) v = 1;
                    List<Unit> newUnits = [
                      Unit(fromCtrl.text.trim(), 1),
                      Unit(toCtrl.text.trim(), 1 / v),
                    ];
                    if (old.units.length > 2) {
                      newUnits.addAll(old.units.sublist(2));
                    }
                    categories[idx] = Category(categoryName, old.emoji, old.color, newUnits, isTemp: old.isTemp);
                  }
                  h['fromUnit'] = 'Category Updated';
                });
                setSheetState(() {});
                _saveHistory();
                _saveCategories();
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasCategory = selected != -1;
    var cat = hasCategory ? categories[selected] : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Converter'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          Stack(
            children: [
              IconButton(onPressed: _showHistoryPage, icon: const Icon(Icons.history)),
              if (history.isNotEmpty)
                Positioned(
                  right: 8, top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('${history.length}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.95,
              ),
              itemCount: categories.length + 1,
              itemBuilder: (context, i) {
                if (i == categories.length) {
                  return GestureDetector(
                    onTap: _showAddCategoryDialog,
                    child: Column(
                      children: [
                        Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, border: Border.all(color: Colors.deepPurple, width: 2)), child: const Center(child: Text('➕', style: TextStyle(fontSize: 28)))),
                        const SizedBox(height: 6),
                        const Text('More', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }
                bool sel = i == selected;
                return GestureDetector(
                  onTap: () => _selectCategory(i),
                  child: Column(
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? categories[i].color : categories[i].color.withOpacity(0.15), border: Border.all(color: sel ? categories[i].color : Colors.grey.shade300, width: 1.5)),
                        child: Center(child: Text(categories[i].emoji, style: const TextStyle(fontSize: 30))),
                      ),
                      const SizedBox(height: 6),
                      Text(categories[i].name, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.bold : FontWeight.normal, color: sel ? categories[i].color : Colors.black), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            if (!hasCategory)
              Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: const Column(children: [Text('👆', style: TextStyle(fontSize: 40)), SizedBox(height: 10), Text('Please select a category', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])),
            if (hasCategory) ...[
              const Text('FROM', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 6),
              TextField(controller: fromCtrl, keyboardType: TextInputType.number, onChanged: (_) => _convert(), decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Enter value', filled: true, fillColor: Colors.white)),
              const SizedBox(height: 12),
              const Text('FROM UNIT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 6),
              _dropdown(cat!.units.map((e) => e.name).toList(), fromUnit, 'Select unit', (v) { setState(() => fromUnit = v); _convert(); }),
              const SizedBox(height: 12),
              Center(child: IconButton(onPressed: () { setState(() { String? t = fromUnit; fromUnit = toUnit; toUnit = t; }); _convert(); }, icon: const Icon(Icons.swap_vert, color: Colors.deepPurple, size: 30))),
              const SizedBox(height: 4),
              const Text('TO UNIT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              const SizedBox(height: 6),
              _dropdown(cat.units.map((e) => e.name).toList(), toUnit, 'Convert to', (v) { setState(() => toUnit = v); _convert(); }),
              const SizedBox(height: 20),
              Container(width: double.infinity, padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.deepPurple, borderRadius: BorderRadius.circular(16)), child: Column(children: [const Text('Result', style: TextStyle(color: Colors.white70)), const SizedBox(height: 6), Text(result.isEmpty ? '---' : '$result $toUnit', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(result.isEmpty ? 'Enter value to convert' : '${fromCtrl.text} $fromUnit = $result $toUnit', style: const TextStyle(color: Colors.white70))])),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _clearAll, icon: const Icon(Icons.clear_all), label: const Text('Clear All'))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dropdown(List<String> items, String? value, String hint, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
      child: DropdownButton<String>(value: value, hint: Text(hint), isExpanded: true, underline: const SizedBox(), items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: onChanged),
    );
  }
}