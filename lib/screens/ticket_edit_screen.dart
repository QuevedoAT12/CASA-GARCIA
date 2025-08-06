// ticket_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'home_screen.dart' show Ticket;

const Color azulPrincipalApp = Color(0xFF194F91);
const Color azulClaroApp = Color(0xFF477BBF);

const Color colorTextoPrincipal = Colors.black87;
const Color colorFondoScaffold = Color(0xFFF4F6F8);
const Color colorError = Colors.redAccent;
const Color colorTextoBlanco = Colors.white;

class TicketEditScreen extends StatefulWidget {
  final Ticket ticketToEdit;

  const TicketEditScreen({Key? key, required this.ticketToEdit}) : super(key: key);

  @override
  State<TicketEditScreen> createState() => _TicketEditScreenState();
}

class _TicketEditScreenState extends State<TicketEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _litersController;
  late TextEditingController _amountController;
  late TextEditingController _dateController;
  late DateTime _selectedDate;
  String? _selectedStatus;

  final List<String> _ticketStatuses = ['Pendiente', 'Aprobado', 'Rechazado', 'En Revisión'];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _litersController = TextEditingController(text: widget.ticketToEdit.liters.toStringAsFixed(2));
    _amountController = TextEditingController(text: widget.ticketToEdit.amount.toStringAsFixed(2));
    _selectedDate = widget.ticketToEdit.dateTimestamp.toDate();
    _dateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(_selectedDate));
    _selectedStatus = widget.ticketToEdit.status;

    if (!_ticketStatuses.contains(_selectedStatus)) {
      _selectedStatus = _ticketStatuses.isNotEmpty ? _ticketStatuses.first : null;
    }
  }

  @override
  void dispose() {
    _litersController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: azulPrincipalApp,
              onPrimary: colorTextoBlanco,
              surface: Colors.white,
              onSurface: colorTextoPrincipal,
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: azulPrincipalApp,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
    }
  }

  Future<void> _saveEditedTicket() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final double? liters = double.tryParse(_litersController.text);
    final double? amount = double.tryParse(_amountController.text);

    if (liters == null || amount == null || _selectedStatus == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos correctamente.'), backgroundColor: colorError),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('tickets')
          .doc(widget.ticketToEdit.id)
          .update({
        'liters': liters,
        'amount': amount,
        'dateTimestamp': Timestamp.fromDate(_selectedDate),
        'dateString': DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate),
        'status': _selectedStatus,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Ticket actualizado exitosamente'), backgroundColor: azulClaroApp),
      );
      Navigator.pop(context, true);

    } catch (e) {
      print("Error al actualizar ticket: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar el ticket: ${e.toString()}'), backgroundColor: colorError),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration(String labelText, String hintText, IconData icon) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(icon, color: azulPrincipalApp),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade400),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: azulClaroApp, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondoScaffold,
      appBar: AppBar(
        title: const Text(
          'Editar Ticket',
          style: TextStyle(color: azulPrincipalApp, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: azulPrincipalApp),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Modifica los datos del ticket:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulPrincipalApp.withOpacity(0.9)),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _litersController,
                decoration: _inputDecoration('Litros Cargados', 'Ej: 45.5', Icons.local_gas_station_outlined),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa los litros.';
                  final l = double.tryParse(value);
                  if (l == null || l <= 0) return 'Ingresa un valor numérico positivo para litros.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                decoration: _inputDecoration('Monto Total (\$)', 'Ej: 850.75', Icons.monetization_on_outlined),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa el monto.';
                  final m = double.tryParse(value);
                  if (m == null || m <= 0) return 'Ingresa un valor numérico positivo para el monto.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dateController,
                decoration: _inputDecoration('Fecha de Carga', '', Icons.calendar_today_outlined)
                    .copyWith(hintText: DateFormat('dd/MM/yyyy').format(_selectedDate)),
                readOnly: true,
                onTap: () => _pickDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor selecciona una fecha.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: _inputDecoration('Estado del Ticket', '', Icons.flag_circle_outlined)
                    .copyWith(),
                items: _ticketStatuses.map((String status) {
                  return DropdownMenuItem<String>(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedStatus = newValue;
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Por favor selecciona un estado.' : null,
                icon: Icon(Icons.arrow_drop_down, color: azulPrincipalApp),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveEditedTicket,
                icon: _isSaving
                    ? Container(
                    width: 20,
                    height: 20,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: colorTextoBlanco))
                    : const Icon(Icons.save_as_outlined, color: colorTextoBlanco),
                label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar Cambios',
                    style: const TextStyle(color: colorTextoBlanco)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulPrincipalApp,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}