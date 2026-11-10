import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ScrapWise reusable text field with optional obscure-text toggle.
class SwTextField extends StatefulWidget {
  const SwTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.validator,
    this.inputFormatters,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
    this.autofillHints,
    this.showPasswordLabel,
    this.hidePasswordLabel,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final String? showPasswordLabel;
  final String? hidePasswordLabel;

  @override
  State<SwTextField> createState() => _SwTextFieldState();
}

class _SwTextFieldState extends State<SwTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _obscure,
      validator: widget.validator,
      inputFormatters: widget.inputFormatters,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      focusNode: widget.focusNode,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
        suffixIcon: widget.obscureText
            ? IconButton(
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
                tooltip: _obscure
                    ? widget.showPasswordLabel ?? 'Show password'
                    : widget.hidePasswordLabel ?? 'Hide password',
              )
            : null,
      ),
    );
  }
}
