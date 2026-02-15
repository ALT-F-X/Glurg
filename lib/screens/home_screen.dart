import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glurg_app/providers/card_provider.dart';
import 'package:glurg_app/widgets/magic_card_display.dart';
import 'package:glurg_app/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _cardNameController = TextEditingController();
  late final FocusNode _cardNameFocus;

  @override
  void initState() {
    super.initState();
    _cardNameFocus = FocusNode();
  }

  @override
  void dispose() {
    _cardNameController.dispose();
    _cardNameFocus.dispose();
    super.dispose();
  }

  void _addCard() {
    final cardName = _cardNameController.text.trim();
    if (cardName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a card name')),
      );
      return;
    }

    context.read<CardListProvider>().addCardByName(cardName);
    _cardNameController.clear();
    _cardNameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Glurg - Creature Combiner'),
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
              tooltip: 'Settings',
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Input Section
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add Creatures to Combine',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cardNameController,
                            focusNode: _cardNameFocus,
                            decoration: InputDecoration(
                              hintText: 'e.g., Grizzly Bears',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) => _addCard(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          onPressed: _addCard,
                          tooltip: 'Add card',
                          child: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Error message display
                    Consumer<CardListProvider>(
                      builder: (context, provider, _) {
                        if (provider.error != null) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              border: Border.all(color: Colors.red),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    provider.error!,
                                    style: TextStyle(color: Colors.red.shade700),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: Colors.red.shade700),
                                  onPressed: provider.clearError,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
              // Merged Card Display
              Consumer<CardListProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (!provider.hasCards) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.layers_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No creatures added yet',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add 2-5 creatures to combine them',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final merged = provider.mergedCard!;
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        MagicCardDisplay(mergedCard: merged),
                        const SizedBox(height: 24),
                        // Remove individual cards button
                        if (provider.cards.length > 1)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Remove Source Cards',
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: provider.cards.length,
                                itemBuilder: (context, index) {
                                  final card = provider.cards[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            card.name,
                                            style: Theme.of(context).textTheme.bodyMedium,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close, size: 18),
                                          onPressed: () {
                                            provider.removeCardAt(index);
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            maxHeight: 32,
                                            maxWidth: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        floatingActionButton: Consumer<CardListProvider>(
          builder: (context, provider, _) {
            if (!provider.hasCards) {
              return const SizedBox.shrink();
            }
            return FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Creatures?'),
                    content: const Text('This will remove all creatures from the combination.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.clearAllCards();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All'),
            );
          },
        ),
      );
    } catch (e) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Text('Error: $e'),
        ),
      );
    }
  }
}
