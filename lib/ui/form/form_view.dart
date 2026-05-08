import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  late final TextEditingController _amountController;
  late final TextEditingController _employeeController;
  late final TextEditingController _observationController;
  late final TextEditingController _dateController;

  CashType _selectedType = CashType.ingress;
  String? _photoPath;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  String? _amountError;
  String? _employeeError;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _employeeController = TextEditingController();
    _observationController = TextEditingController();
    _dateController = TextEditingController();

    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _employeeController.dispose();
    _observationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedType == CashType.ingress ? 'Nova Receita' : 'Novo Gasto'),
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
            _buildObservationField(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildPhotoField(),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _isSubmitting ? null : _saveLog,
              child: const Text('Salvar Registro'),
            )
          ],
        ),
      ),
      bottomNavigationBar: const BottomBar(),
    );
  }

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
        decoration: InputDecoration(
          labelText: 'Valor',
          prefixText: 'R\$ ',
          errorText: _amountError,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.attach_money),
        ),
        onChanged: (value) {
          if (_amountError != null) {
            setState(() => _amountError = null);
          }
        }
      ),
    );
  }

  Widget _buildEmployeeField() {
    return Card(
      child: TextField(
        controller: _employeeController,
        decoration: InputDecoration(
          labelText: 'Funcionário',
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.person),
          errorText: _employeeError
        ),
        onChanged: (value) {
          if (_employeeError != null) {
            setState(() => _employeeError = null);
          }
        },
      ),
    );
  }

  Widget _buildObservationField() {
    return Card(
      child: TextField(
        controller: _observationController,
        decoration: const InputDecoration(
          labelText: 'Observação (opcional)',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.question_answer),
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
              labelText: 'Data',
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

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = TimeOfDay.fromDateTime(_selectedDate);

      setState(() {
        _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
      });
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


  Future<void> _saveLog() async {
    if (_isSubmitting) return;

    final cleanAmountText = _amountController.text.replaceAll(',', '.');
    final newAmount = double.tryParse(cleanAmountText);
    final newEmployee = _employeeController.text.trim();
    final obsText = _observationController.text.trim();
    final finalObservation = obsText.isEmpty ? null : obsText;

    bool hasError = false;

    setState(() {
      _amountError = null;
      _employeeError = null;

      if (newAmount == null || newAmount <= 0) {
        _amountError = 'Digite um número válido';
        hasError = true;
      }

      if (newEmployee.isEmpty) {
        _employeeError = 'Digite o nome do funcionário';
        hasError = true;
      }
    });

    if (hasError) return;

    setState(() => _isSubmitting = true);

    try {
      final log = CashLog(
        id: const Uuid().v4(),
        type: _selectedType,
        photoPath: _photoPath,
        amount: newAmount!,
        observation: finalObservation,
        employeeName: newEmployee,
        date: _selectedDate,
        isSynced: false,
      );

      await ref.read(cashLogsProvider(false).notifier).addLog(log);

      if (!mounted) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salvo com sucesso!'),
          ),
        );

        _amountController.clear();
        _employeeController.clear();
        _observationController.clear();

        setState(() {
          _photoPath = null;
          _selectedDate = DateTime.now();
          _selectedType = CashType.ingress;
        });
      });
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