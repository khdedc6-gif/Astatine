import 'package:flutter/material.dart';
import 'flashcard_models.dart';
import 'flashcard_service.dart';
import 'deck_detail_screen.dart';
import 'flashcard_settings_dialog.dart';

class FlashcardsDashboardScreen extends StatefulWidget {
  const FlashcardsDashboardScreen({super.key});
  @override
  State<FlashcardsDashboardScreen> createState() => _State();
}

class _State extends State<FlashcardsDashboardScreen> {
  List<FlashcardDeck> _decks = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final decks = await FlashcardService.getDecks();
    setState(() {
      _decks = decks;
      _loading = false;
    });
  }

  void _showCreate() {
    final tCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    final rCtrl = TextEditingController();
    bool bulk = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          title: const Text('Tạo Bộ Thẻ', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: tCtrl, decoration: const InputDecoration(labelText: 'Tên')),
                TextField(controller: dCtrl, decoration: const InputDecoration(labelText: 'Mô tả')),
                SwitchListTile(
                  title: const Text('Nhập nhanh', style: TextStyle(color: Colors.white, fontSize: 13)),
                  value: bulk,
                  onChanged: (v) => setDlg(() => bulk = v),
                ),
                if (bulk) TextField(controller: rCtrl, maxLines: 4, decoration: const InputDecoration(hintText: 'Q1 | A1')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (tCtrl.text.isEmpty) return;
                final deck = bulk && rCtrl.text.isNotEmpty
                    ? FlashcardService.importFromBulkText(title: tCtrl.text, description: dCtrl.text, rawText: rCtrl.text)
                    : FlashcardDeck(id: DateTime.now().millisecondsSinceEpoch.toString(), title: tCtrl.text, description: dCtrl.text, cards: [], createdAt: DateTime.now());
                await FlashcardService.saveDeck(deck);
                Navigator.pop(context);
                _load();
              },
              child: const Text('Tạo'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _decks.where((d) => d.title.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF11111B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181825),
        title: const Text('Flashcard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => showDialog(context: context, builder: (_) => const FlashcardSettingsDialog()),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm...',
                      filled: true,
                      fillColor: const Color(0xFF181825),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(onPressed: _showCreate, child: const Text('Tạo bộ thẻ')),
              ],
            ),
            const SizedBox(height: 24),
            _loading
                ? const Expanded(child: Center(child: CircularProgressIndicator()))
                : Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final d = filtered[i];
                        return Card(
                          color: const Color(0xFF181825),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(d.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('${d.totalCards} thẻ', style: const TextStyle(color: Colors.white70)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await FlashcardService.deleteDeck(d.id);
                                _load();
                              },
                            ),
                            onTap: () async {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => DeckDetailScreen(deck: d)));
                              _load();
                            },
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
