import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:glurg_app/models/card.dart';

class CardTile extends StatelessWidget {
  final MtgCard card;
  final VoidCallback onRemove;

  const CardTile({
    Key? key,
    required this.card,
    required this.onRemove,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Image
          if (card.imageUrl != null && card.imageUrl!.isNotEmpty)
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: CachedNetworkImage(
                  imageUrl: card.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade300,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Container(
                color: Colors.grey.shade300,
                child: const Center(
                  child: Icon(Icons.broken_image),
                ),
              ),
            ),
          // Card Info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Name
                Text(
                  card.name,
                  style: Theme.of(context).textTheme.labelLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Mana Value and Type
                Row(
                  children: [
                    if (card.manaValue > 0)
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            card.manaValue.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    if (card.power != null && card.toughness != null)
                      Text(
                        '${card.power}/${card.toughness}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Type line
                Text(
                  card.type,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                // Remove button
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Remove', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
