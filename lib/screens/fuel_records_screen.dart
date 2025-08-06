import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ticket_capture_screen.dart';
import 'ticket_edit_screen.dart';
import 'home_screen.dart' show Ticket;

class FuelRecordsScreen extends StatefulWidget {
  const FuelRecordsScreen({Key? key}) : super(key: key);

  @override
  _FuelRecordsScreenState createState() => _FuelRecordsScreenState();
}

class _FuelRecordsScreenState extends State<FuelRecordsScreen> {
  static const Color azulPrincipalApp = Color(0xFF194F91);
  static const Color azulClaroApp = Color(0xFF477BBF);
  static const Color azulGrisAccion = Color(0xFF607D8B);
  static const Color colorTextoPrincipal = Colors.black87;
  static const Color colorTextoSecundario = Colors.black54;
  static const Color colorFondoScaffold = Color(0xFFF4F6F8);
  static const Color colorError = Colors.redAccent;

  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _filterValueController = TextEditingController();

  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  List<Ticket> _allTickets = [];
  List<Ticket> _filteredTickets = [];
  bool _isLoading = true;
  String? _errorMessage;

  DocumentSnapshot? _lastVisibleDocument;
  bool _isLoadingMore = false;
  bool _hasMoreTickets = true;
  final int _ticketsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchTicketsForCurrentUser(isInitialLoad: true);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMoreTickets &&
          !_isLoading) {
        _fetchTicketsForCurrentUser();
      }
    });
  }

  Future<void> _fetchTicketsForCurrentUser({bool isInitialLoad = false}) async {
    if (_isLoadingMore && !isInitialLoad) return;

    if (mounted) {
      setState(() {
        if (isInitialLoad) {
          _isLoading = true;
          _allTickets.clear();
          _filteredTickets.clear();
          _lastVisibleDocument = null;
          _hasMoreTickets = true;
        }
        _isLoadingMore = !isInitialLoad;
        _errorMessage = null;
      });
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = "Usuario no autenticado.";
          _hasMoreTickets = false;
          _allTickets = [];
          _filteredTickets = [];
        });
      }
      return;
    }

    try {
      Query query = FirebaseFirestore.instance
          .collection('tickets')
          .where('userId', isEqualTo: user.uid);

      if (_selectedStartDate != null && isInitialLoad) {
        query = query.where('dateTimestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(
            DateTime(_selectedStartDate!.year, _selectedStartDate!.month, _selectedStartDate!.day)
        ));
      }
      if (_selectedEndDate != null && isInitialLoad) {
        query = query.where('dateTimestamp', isLessThanOrEqualTo: Timestamp.fromDate(
            DateTime(_selectedEndDate!.year, _selectedEndDate!.month, _selectedEndDate!.day, 23, 59, 59)
        ));
      }
      query = query.orderBy('dateTimestamp', descending: true);

      if (_lastVisibleDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastVisibleDocument!);
      }

      QuerySnapshot querySnapshot = await query.limit(_ticketsPerPage).get();

      if (querySnapshot.docs.isNotEmpty) {
        _lastVisibleDocument = querySnapshot.docs.last;
        final newTickets = querySnapshot.docs
            .map((doc) => Ticket.fromFirestore(doc))
            .toList();
        _allTickets.addAll(newTickets);
      }

      if (querySnapshot.docs.length < _ticketsPerPage) {
        _hasMoreTickets = false;
      }

      _applyClientSideFilters(updateState: false);
    } catch (e) {
      print("Error al cargar tickets en FuelRecordsScreen: $e");
      _errorMessage = "Error al cargar los tickets: ${e.toString()}";
      _hasMoreTickets = false;
      if (e is FirebaseException && e.code == 'failed-precondition') {
        print("Sugerencia de índice para FuelRecordsScreen: ${e.message}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error de base de datos: ${e.message}. Contacta a soporte si persiste.'),
              backgroundColor: colorError,
              duration: const Duration(seconds: 7),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _filterValueController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addRecord() {
    Navigator.pushNamed(context, '/capture-ticket').then((value) {
      if (value == true || value == null) {
        _fetchTicketsForCurrentUser(isInitialLoad: true);
      }
    });
  }

  Widget _buildFilterTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      onTap: onTap,
      style: const TextStyle(color: colorTextoPrincipal),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: colorTextoSecundario.withOpacity(0.7)),
        prefixIcon: Icon(icon, color: azulPrincipalApp.withOpacity(0.8)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: azulPrincipalApp, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _selectedStartDate : _selectedEndDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: azulPrincipalApp,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: colorTextoPrincipal,
              ),
              dialogBackgroundColor: Colors.white,
              textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: azulPrincipalApp)
              )
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final formattedDate = DateFormat('dd/MM/yyyy').format(picked);
      controller.text = formattedDate;
      if (mounted) {
        if (isStartDate) {
          _selectedStartDate = picked;
          if (_selectedEndDate != null && _selectedEndDate!.isBefore(picked)) {
            _selectedEndDate = picked;
            _endDateController.text = DateFormat('dd/MM/yyyy').format(picked);
          }
        } else {
          if (_selectedStartDate != null && picked.isBefore(_selectedStartDate!)) {
            _selectedEndDate = _selectedStartDate;
            _endDateController.text = DateFormat('dd/MM/yyyy').format(_selectedStartDate!);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La fecha de fin no puede ser anterior a la fecha de inicio.'), backgroundColor: colorError),
            );
          } else {
            _selectedEndDate = picked;
          }
        }
      }
    }
  }

  void _applyFiltersAndReload() {
    _fetchTicketsForCurrentUser(isInitialLoad: true);
  }

  void _applyClientSideFilters({bool updateState = true}) {
    List<Ticket> tempFiltered = _allTickets;

    if (_filterValueController.text.isNotEmpty) {
      final filterLiters = double.tryParse(_filterValueController.text);
      if (filterLiters != null) {
        tempFiltered = tempFiltered.where((ticket) => ticket.liters == filterLiters).toList();
      }
    }

    if (updateState) {
      if (mounted) {
        setState(() {
          _filteredTickets = tempFiltered;
          if (_filteredTickets.isEmpty && (_filterValueController.text.isNotEmpty || _selectedStartDate != null || _selectedEndDate != null)) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: const Text('No se encontraron tickets con los filtros aplicados.'),
                  backgroundColor: azulClaroApp.withOpacity(0.9)),
            );
          }
        });
      }
    } else {
      _filteredTickets = tempFiltered;
    }
  }

  void _clearFilters() {
    _startDateController.clear();
    _endDateController.clear();
    _filterValueController.clear();
    _selectedStartDate = null;
    _selectedEndDate = null;
    _fetchTicketsForCurrentUser(isInitialLoad: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Filtros limpiados. Recargando...'), backgroundColor: azulClaroApp.withOpacity(0.9)),
      );
    }
  }

  void _deleteTicket(Ticket ticketToDelete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que deseas eliminar el ticket de ${ticketToDelete.liters}L del ${ticketToDelete.dateString}?'),
          actions: <Widget>[
            TextButton(
              child: Text('Cancelar', style: TextStyle(color: azulGrisAccion)),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Eliminar', style: TextStyle(color: colorError)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('tickets').doc(ticketToDelete.id).delete();
        _allTickets.removeWhere((ticket) => ticket.id == ticketToDelete.id);
        _filteredTickets.removeWhere((ticket) => ticket.id == ticketToDelete.id);
        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Ticket eliminado exitosamente.'), backgroundColor: azulPrincipalApp),
          );
        }
      } catch (e) {
        print("Error al eliminar ticket: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar el ticket: ${e.toString()}'), backgroundColor: colorError),
          );
        }
      }
    }
  }

  void _editTicket(Ticket ticketToEdit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketEditScreen(ticketToEdit: ticketToEdit),
      ),
    ).then((result) {
      if (result == true) {
        _fetchTicketsForCurrentUser(isInitialLoad: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondoScaffold,
      appBar: AppBar(
        title: const Text(
          'Mis Tickets de Carga',
          style: TextStyle(color: azulPrincipalApp, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: azulPrincipalApp),
      ),
      body: RefreshIndicator(
        onRefresh: () => _fetchTicketsForCurrentUser(isInitialLoad: true),
        color: azulPrincipalApp,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.15),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtrar Tickets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorTextoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFilterTextField(
                            controller: _startDateController,
                            hintText: 'Fecha Inicio',
                            icon: Icons.calendar_today_outlined,
                            readOnly: true,
                            onTap: () => _selectDate(context, _startDateController, true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildFilterTextField(
                            controller: _endDateController,
                            hintText: 'Fecha Fin',
                            icon: Icons.event_outlined,
                            readOnly: true,
                            onTap: () => _selectDate(context, _endDateController, false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildFilterTextField(
                      controller: _filterValueController,
                      hintText: 'Filtrar por Litros (ej: 50.5)',
                      icon: Icons.local_gas_station_outlined,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _applyFiltersAndReload,
                            icon: const Icon(Icons.filter_alt_outlined, size: 20),
                            label: const Text('Aplicar Filtro'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: azulPrincipalApp,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: Icon(Icons.clear_all_outlined, size: 20, color: colorTextoSecundario),
                          label: Text('Limpiar', style: TextStyle(color: colorTextoSecundario)),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.grey.shade300))),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading && _allTickets.isEmpty)
                const Expanded(child: Center(child: CircularProgressIndicator(color: azulPrincipalApp)))
              else if (_errorMessage != null && _allTickets.isEmpty)
                Expanded(child: Center(child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: colorError, fontSize: 16))))
              else ...[
                  if (_filteredTickets.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Resultados (${_filteredTickets.length}${_hasMoreTickets && _allTickets.length >= _ticketsPerPage ? '+' : ''})',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorTextoSecundario),
                      ),
                    ),
                  Expanded(
                    child: _filteredTickets.isEmpty && !_isLoading && !_isLoadingMore
                        ? Center(
                      child: Text(
                        _allTickets.isEmpty && _filterValueController.text.isEmpty && _selectedStartDate == null && _selectedEndDate == null
                            ? 'No tienes tickets registrados aún.'
                            : 'No hay tickets que coincidan con los filtros.',
                        style: TextStyle(color: colorTextoSecundario, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    )
                        : ListView.builder(
                      controller: _scrollController,
                      itemCount: _filteredTickets.length + (_hasMoreTickets ? 1 : 0),
                      itemBuilder: (BuildContext context, int index) {
                        if (index == _filteredTickets.length && _hasMoreTickets) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Center(child: CircularProgressIndicator(color: azulPrincipalApp)),
                          );
                        }
                        if (index >= _filteredTickets.length) return const SizedBox.shrink();

                        final ticket = _filteredTickets[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: azulPrincipalApp.withOpacity(0.15),
                              child: Text(
                                '${ticket.liters.toStringAsFixed(ticket.liters % 1 == 0 ? 0 : 1)}',
                                style: const TextStyle(color: azulPrincipalApp, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            title: Text('Monto: \$${ticket.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500, color: colorTextoPrincipal)),
                            subtitle: Text('Fecha: ${ticket.dateString}\nEstado: ${ticket.status ?? 'N/A'}', style: TextStyle(color: colorTextoSecundario)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit_outlined, color: azulClaroApp, size: 22),
                                  onPressed: () => _editTicket(ticket),
                                  tooltip: 'Editar',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: colorError, size: 22),
                                  onPressed: () => _deleteTicket(ticket),
                                  tooltip: 'Eliminar',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isLoadingMore && _allTickets.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: azulPrincipalApp))),
                    ),
                ]
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRecord,
        label: const Text('Agregar Ticket'),
        icon: const Icon(Icons.add_circle_outline),
        backgroundColor: azulPrincipalApp,
        foregroundColor: Colors.white,
      ),
    );
  }
}