import 'package:flutter/material.dart';

class SubstitutionDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> substitutionData;
  final Function(Map<String, dynamic>) onAccept;

  const SubstitutionDetailsDialog({
    super.key,
    required this.substitutionData,
    required this.onAccept,
  });

  @override
  State<SubstitutionDetailsDialog> createState() => _SubstitutionDetailsDialogState();
}

class _SubstitutionDetailsDialogState extends State<SubstitutionDetailsDialog> {
  @override
  Widget build(BuildContext context) {
    final data = widget.substitutionData;
    final original = data['original'];
    final substitute = data['substitute'];
    final deltas = data['deltas'];
    final rule = data['rule'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingredient Substitution',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF184E77),
              ),
            ),
            const SizedBox(height: 16),
            
            // Original ingredient
            _buildIngredientCard(
              'Original',
              original['ingredient'],
              original['amount_g'],
              original['calories'],
              original['cost'],
            ),
            
            const SizedBox(height: 12),
            const Icon(Icons.arrow_downward, color: Color(0xFF76C893), size: 24),
            const SizedBox(height: 12),
            
            // Substitute ingredient
            _buildIngredientCard(
              'Substitute',
              substitute['ingredient'],
              substitute['amount_g'],
              substitute['calories'],
              substitute['cost'],
            ),
            
            const SizedBox(height: 16),
            
            // Deltas
            Card(
              color: Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Changes:',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF184E77),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDeltaRow('Cost', deltas['cost'], '₱'),
                    _buildDeltaRow('Calories', deltas['calories'], 'kcal'),
                    _buildDeltaRow('Sodium', deltas['sodium'], 'mg'),
                  ],
                ),
              ),
            ),
            
            if (rule != null && rule['notes'] != null) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFE8F5E8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, size: 16, color: Color(0xFF184E77)),
                          const SizedBox(width: 8),
                          Text(
                            'Chef\'s Note',
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF184E77),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rule['notes'],
                        style: const TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 20),
            
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFF184E77),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontFamily: 'Orbitron'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onAccept(data);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF76C893),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontFamily: 'Orbitron'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientCard(String title, Map<String, dynamic> ingredient, 
      double amountG, double calories, double cost) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                color: Color(0xFF184E77),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ingredient['ingredientName'],
              style: const TextStyle(
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Amount: ${_formatAmount(amountG)}',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12),
            ),
            Text(
              'Calories: ${calories.toStringAsFixed(1)} kcal',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12),
            ),
            Text(
              'Cost: ₱${cost.toStringAsFixed(2)}',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeltaRow(String label, double delta, String unit) {
    final isPositive = delta > 0;
    final isNegative = delta < 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12),
            ),
          ),
          Text(
            '${isPositive ? '+' : ''}${delta.toStringAsFixed(2)} $unit',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.red : (isNegative ? Colors.green : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double grams) {
    if (grams >= 1000) {
      return '${(grams / 1000).toStringAsFixed(1)} kg';
    } else {
      return '${grams.toStringAsFixed(1)} g';
    }
  }
}