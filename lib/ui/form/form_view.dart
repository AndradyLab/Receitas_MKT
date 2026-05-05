import 'dart:io'; // Adicionado para corrigir o erro do File()
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Importação do Riverpod necessária
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:receitas_mkt/ui/widgets/shared_widgets.dart';
import 'package:uuid/uuid.dart';

import '../../data/cash_log_model.dart';
import '../../logic/cash_logic_provider.dart';

class FormView extends ConsumerStatefulWidget {
  const FormView({super.key});

  @override
  ConsumerState<FormView> createState() => _FormViewState();
}

class _FormViewState extends ConsumerState<FormView> {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  late final TextEditingController _amountController;
  late final TextEditingController _employeeController;
  late final TextEditingController _productsController;
  late final TextEditingController _dateController;

  CashType _selectedType = CashType.ingress;
  String? _photoPath;
  DateTime _selectedDate = DateTime.now();
  bool _isFormValid = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _employeeController = TextEditingController();
    _productsController = TextEditingController();
    _dateController = TextEditingController();

    _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _employeeController.dispose();
    _productsController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _updateFormValidation() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    final employee = _employeeController.text.trim();

    setState(() {
      _isFormValid = amount != null && employee.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedType == CashType.ingress ? 'Nova Receita' : 'Novo Gasto'),
        actions: [
          if (_isSubmitting)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isFormValid ? _saveLog : null,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 24),
            _buildAmountField(),
            const SizedBox(height: 16),
            _buildEmployeeField(),
            const SizedBox(height: 16),
            _buildProductsField(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildPhotoField(),
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: const BottomBar(),
    );
  }

  // Métodos de construção de UI mantidos como no seu código...
  Widget _buildTypeSelector() {
    return Card(
      child: ListTile(
        leading: Icon(_selectedType == CashType.ingress ? Icons.arrow_upward : Icons.arrow_downward),
        title: const Text('Selecione o Tipo'),
        subtitle: Text(_selectedType == CashType.ingress ? ' Receita' : ' Despesa'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              color: _selectedType == CashType.ingress ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => setState(() => _selectedType = CashType.ingress),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              color: _selectedType == CashType.egress ? Theme.of(context).colorScheme.primary : null,
              onPressed: () => setState(() => _selectedType = CashType.egress),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField() {
    return Card(
      child: TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Valor',
          prefixText: 'R\$ ',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.attach_money),
        ),
        onChanged: (_) => _updateFormValidation(),
      ),
    );
  }

  Widget _buildEmployeeField() {
    return Card(
      child: TextField(
        controller: _employeeController,
        decoration: const InputDecoration(
          labelText: 'Funcionário',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.person),
        ),
        onChanged: (_) => _updateFormValidation(),
      ),
    );
  }

  Widget _buildProductsField() {
    return Card(
      child: TextField(
        controller: _productsController,
        decoration: const InputDecoration(
          labelText: 'Produtos (opcional)',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.production_quantity_limits),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Card(
      child: InkWell(
        onTap: _selectDate,
        child: IgnorePointer(
          child: TextField(
            controller: _dateController,
            decoration: const InputDecoration(
              labelText: 'Data e Hora',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_photoPath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Image.file(File(_photoPath!), height: 200, fit: BoxFit.cover),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.camera), label: const Text('Câmera')),
                ElevatedButton.icon(onPressed: _pickFromGallery, icon: const Icon(Icons.photo), label: const Text('Galeria')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Lógica de manipulação de dados
  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          _dateController.text = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate);
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera);
    if (file != null) setState(() => _photoPath = file.path);
  }

  Future<void> _pickFromGallery() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _photoPath = file.path);
  }

  void _clearPhoto() => setState(() => _photoPath = null);

  Future<void> _saveLog() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final employee = _employeeController.text.trim();
      final products = _productsController.text.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

      final log = CashLog(
        id: const Uuid().v4(), // Usando UUID para gerar ID único
        type: _selectedType,
        photoPath: _photoPath,
        amount: amount,
        products: products,
        employeeName: employee,
        date: _selectedDate,
        isSynced: false,
      );

      await ref.read(cashLogsProvider.notifier).addLog(log);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salvo com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}