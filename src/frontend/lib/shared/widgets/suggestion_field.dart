import 'package:flutter/material.dart';

/// Free text with suggestions that match what was typed (e.g. known marketplaces or
/// categories). Anything can be typed; picking a suggestion only avoids variations.
class SuggestionField extends StatefulWidget {
  const SuggestionField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.labelText,
    this.helperText,
    this.errorText,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String labelText;
  final String? helperText;
  final String? errorText;
  final TextCapitalization textCapitalization;

  @override
  State<SuggestionField> createState() => _SuggestionFieldState();
}

class _SuggestionFieldState extends State<SuggestionField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final typed = value.text.trim().toLowerCase();
        return widget.suggestions.where(
          (s) => typed.isEmpty || s.toLowerCase().contains(typed),
        );
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: widget.textCapitalization,
            decoration: InputDecoration(
              labelText: widget.labelText,
              helperText: widget.helperText,
              errorText: widget.errorText,
            ),
          ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 400),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final option in options)
                  ListTile(
                    title: Text(option),
                    onTap: () => onSelected(option),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
