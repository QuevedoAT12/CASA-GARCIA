import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

// Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Importa el paquete image para redimensionar
import 'package:image/image.dart' as img;
// Importa path_provider para obtener el directorio temporal
import 'package:path_provider/path_provider.dart';

// Importa tu NotificationProvider (asegúrate que la ruta sea correcta)
import '../providers/notification_provider.dart'; // Ajusta esta ruta si es necesario

// --- NUEVOS COLORES DE LA APP ---
const Color azulPrincipalApp = Color(0xFF194F91);
const Color azulClaroApp = Color(0xFF477BBF);
// --- FIN NUEVOS COLORES ---

// Colores adicionales para esta pantalla
const Color colorTextoPrincipal = Colors.black87;
const Color colorFondoScaffold = Color(0xFFF4F6F8);
const Color colorError = Colors.redAccent;
const Color colorTextoBlanco = Colors.white;

class TicketValidationScreen extends StatefulWidget {
  final File imageFile;

  const TicketValidationScreen({Key? key, required this.imageFile})
      : super(key: key);

  @override
  State<TicketValidationScreen> createState() => _TicketValidationScreenState();
}

class _TicketValidationScreenState extends State<TicketValidationScreen> {
  String _fullRecognizedText = '';
  bool _isProcessing = true;
  bool _isSaving = false;

  late TextEditingController _dateController;
  late TextEditingController _litersController;
  late TextEditingController _subtotalController; // Nuevo
  late TextEditingController _ivaController; // Nuevo
  late TextEditingController _amountController; // Representará el TOTAL
  late TextEditingController _vehiclePlateController;

  String? _initialDate;
  String? _initialLiters;
  String? _initialSubtotal; // Nuevo
  String? _initialIva; // Nuevo
  String? _initialAmount; // TOTAL
  String? _initialVehiclePlate;

  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);
  final TransformationController _transformationController =
  TransformationController();

  Future<File> _getResizedImage(File originalFile,
      {int maxWidth = 1280, int quality = 90}) async {
    print("--- Iniciando redimensionamiento de imagen ---");
    try {
      final bytes = await originalFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        print(
            "No se pudo decodificar la imagen para redimensionar. Usando original.");
        return originalFile;
      }

      if (originalImage.width > maxWidth) {
        print(
            "Redimensionando imagen de ${originalImage.width}px a ${maxWidth}px de ancho (calidad: $quality%).");
        img.Image resizedImage = img.copyResize(originalImage, width: maxWidth);
        final resizedBytes = img.encodeJpg(resizedImage, quality: quality);
        final tempDir = await getTemporaryDirectory();
        final fileName = 'resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
        File resizedFile = File('${tempDir.path}/$fileName');
        await resizedFile.writeAsBytes(resizedBytes);
        print(
            "Imagen redimensionada y guardada en: ${resizedFile.path} (Tamaño: ${resizedBytes.lengthInBytes} bytes)");
        return resizedFile;
      } else {
        print(
            "La imagen no necesita redimensionamiento (ancho actual: ${originalImage.width}px).");
        return originalFile;
      }
    } catch (e) {
      print(
          "Error durante el redimensionamiento de la imagen: $e. Usando original.");
      return originalFile;
    }
  }

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController();
    _litersController = TextEditingController();
    _subtotalController = TextEditingController(); // Nuevo
    _ivaController = TextEditingController(); // Nuevo
    _amountController = TextEditingController(); // Total
    _vehiclePlateController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.addNotification(
          'Ticket Recibido para Validación',
          'La imagen de tu ticket está lista. Por favor, revisa y corrige los datos extraídos a continuación.',
        );
      }
    });

    _performTextRecognitionAndParse();
  }

// BEGIN: _parseTicketData (Función completa y actualizada)
// BEGIN: _parseTicketData (Función completa y actualizada)
  void _parseTicketData(String text) {
    if (text.isEmpty) return;
    final String upperCaseText = text.toUpperCase();
    print("--- Texto Completo Reconocido (MAYÚSCULAS) para Parsear ---");
    print(upperCaseText);
    print("--- Fin del Texto Completo ---");

    final lines = upperCaseText.split('\n');
    String? foundDate;
    String? foundLiters;
    String? foundAmount; // TOTAL
    String? foundSubtotal;
    String? foundIva;
    String? foundVehiclePlate;

    // --- EXPRESIONES REGULARES ---
    final dateRegex = RegExp(r'\b(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.](\d{4}|\d{2}))\b');
    final genericLitersRegex =
    RegExp(r'([\d,\.]+)\s*L(?:TR|TS|ITROS)?\b', caseSensitive: false);

    final totalKeywordRegex = RegExp(
        r'\b(?:TOTAL|IMPORTE\s*TOTAL|NETO\s*A\s*PAGAR|CANTIDAD\s*PAGADA|GRAN\s*TOTAL)\s*[:\$€MXN]*\s*([\d,\.]+)\b',
        caseSensitive: false);
    final subtotalKeywordRegex = RegExp(
      // Keyword para subtotal + monto en la misma línea
        r'\b(?:SUBTOTAL|SUB-TOTAL|SUB\s*TOTAL|BASE\s*IMPONIBLE|SUMA)\s*[:\$€MXN]*\s*([\d,\.]+)\b',
        caseSensitive: false);
    final subtotalLabelRegex = RegExp(
      // Solo la etiqueta de subtotal (para buscar monto en línea siguiente)
        r'\b(SUBTOTAL|SUB-TOTAL|SUB\s*TOTAL|BASE\s*IMPONIBLE|SUMA)\s*[:]?\s*$',
        caseSensitive: false);

    final ivaLabelRegex = RegExp(
        r'\b(IVA|I\.V\.A|JVA|IMPUESTO)\s*(?:\(\s*\d{1,2}(?:\.\d+)?\s*%\s*\))?\s*[:]?\s*([\d,\.]+)?\b',
        caseSensitive: false);
    final specificIvaKeywordsForNextLineCheck =
    RegExp(r'\b(IVA|I\.V\.A|JVA|IMPUESTO)\b');

    final amountCurrencyRegex =
    RegExp(r'\b([\$€MXN]?\s*[\d,]+\.\d{2})\b', caseSensitive: false);
    final amountSimpleNumberRegex = RegExp(r'^\s*([\d,]+\.\d{2})\s*$', caseSensitive: false);

    final specificPlateAfterVehicleKeywordRegex = RegExp(
        r'VE(H|W)[IÍ]?CUL[O0]\s*:\s*([A-Z0-9\-]{6,10})\b',
        caseSensitive: false);
    final strictValidPlatePatternRegex = RegExp(r'^[A-Z0-9]{6,7}$');
    final notOnlyNumbersRegex = RegExp(r'^[0-9]+$');

    List<Map<String, dynamic>> potentialAmountsGeneric = []; // Guardará {value: "123.45", lineIndex: i, type: "..."}

    // --- BÚSQUEDA DE PLACA DEL VEHÍCULO ---
    for (String line in lines) {
      if (foundVehiclePlate != null) break;
      String currentLine = line.trim();
      if (currentLine.isEmpty) continue;

      Match? plateMatch =
      specificPlateAfterVehicleKeywordRegex.firstMatch(currentLine);

      if (plateMatch != null && plateMatch.group(2) != null) {
        String originalCapturedPlate = plateMatch.group(2)!.toUpperCase();
        String plateForValidation = originalCapturedPlate.replaceAll('-', '');
        print(
            "Candidato a placa (grupo 2 - original): $originalCapturedPlate en línea '$currentLine'");

        if (strictValidPlatePatternRegex.hasMatch(plateForValidation) &&
            !notOnlyNumbersRegex.hasMatch(plateForValidation)) {
          foundVehiclePlate = originalCapturedPlate;
          print("Placa ENCONTRADA y VALIDADA: $foundVehiclePlate");
          break;
        } else {
          print(
              "Candidato a placa '$originalCapturedPlate' no pasó la validación adicional.");
        }
      }
    }
    if (foundVehiclePlate == null) {
      print(
          "No se encontró ninguna placa de vehículo con el patrón 'VEHICULO : [PLACA]'.");
    }

    // --- BÚSQUEDA DE FECHA, LITROS, Y CANDIDATOS A MONTOS ---
    for (int i = 0; i < lines.length; i++) {
      String lineContent = lines[i].trim();
      if (lineContent.isEmpty) continue;

      // Fecha
      if (foundDate == null) {
        final dateMatch = dateRegex.firstMatch(lineContent);
        if (dateMatch != null && dateMatch.group(1) != null) {
          foundDate = dateMatch.group(1);
          print("Fecha encontrada: $foundDate en línea '$lineContent'");
        }
      }

      // Litros
      if (foundLiters == null) {
        Match? litersMatch = genericLitersRegex.firstMatch(lineContent);
        if (litersMatch != null && litersMatch.group(1) != null) {
          foundLiters = litersMatch.group(1);
          print("Litros encontrados: $foundLiters en línea '$lineContent'");
        }
      }

      // Candidato a TOTAL (con keyword fuerte)
      Match? totalMatch = totalKeywordRegex.firstMatch(lineContent);
      if (totalMatch != null && totalMatch.group(1) != null) {
        String val = _cleanNumericValue(totalMatch.group(1)) ?? "";
        if (val.isNotEmpty) {
          potentialAmountsGeneric.add(
              {'value': val, 'type': 'total_keyword', 'line': i});
          print("Candidato a TOTAL (keyword): $val en línea '$lineContent'");
          if (foundAmount == null) foundAmount = val;
        }
      }

      // Candidato a SUBTOTAL (con keyword fuerte en la misma línea)
      Match? subtotalKeywordMatch = subtotalKeywordRegex.firstMatch(lineContent);
      if (subtotalKeywordMatch != null && subtotalKeywordMatch.group(1) != null) {
        String val = _cleanNumericValue(subtotalKeywordMatch.group(1)) ?? "";
        if (val.isNotEmpty) {
          potentialAmountsGeneric.add(
              {'value': val, 'type': 'subtotal_keyword', 'line': i});
          print(
              "Candidato a SUBTOTAL (keyword en línea): $val en línea '$lineContent'");
        }
      }

      // Candidato a IVA (con keyword, puede tener valor en misma línea o siguiente)
      Match? ivaLineMatch = ivaLabelRegex.firstMatch(lineContent);
      if (ivaLineMatch != null) {
        if (ivaLineMatch.group(2) != null && ivaLineMatch.group(2)!.isNotEmpty) {
          // Valor en la misma línea
          String val = _cleanNumericValue(ivaLineMatch.group(2)) ?? "";
          if (val.isNotEmpty) {
            potentialAmountsGeneric.add(
                {'value': val, 'type': 'iva_keyword_same_line', 'line': i});
            print(
                "Candidato a IVA (keyword, misma línea): $val en línea '$lineContent'");
          }
        } else if (specificIvaKeywordsForNextLineCheck.hasMatch(lineContent) &&
            i + 1 < lines.length) {
          // Solo keyword, buscar en siguiente
          String nextLine = lines[i + 1].trim();
          Match? ivaValueMatchNextLine = amountSimpleNumberRegex.firstMatch(nextLine) ??
              amountCurrencyRegex.firstMatch(nextLine);
          if (ivaValueMatchNextLine != null &&
              ivaValueMatchNextLine.group(1) != null) {
            String val = _cleanNumericValue(
                ivaValueMatchNextLine.group(1)!.replaceAll(RegExp(r'[\$€MXN\s]'), '')) ??
                "";
            if (val.isNotEmpty) {
              potentialAmountsGeneric.add(
                  {'value': val, 'type': 'iva_keyword_next_line', 'line': i + 1});
              print(
                  "Candidato a IVA (keyword, sig. línea): $val en línea '$nextLine'");
            }
          }
        }
      }

      // Candidato a SUBTOTAL (solo etiqueta, buscar valor en siguiente línea)
      Match? subtotalLabelOnlyMatch = subtotalLabelRegex.firstMatch(lineContent);
      if (subtotalLabelOnlyMatch != null && i + 1 < lines.length) {
        bool alreadyFoundSubtotalWithValueThisLine =
        subtotalKeywordRegex.hasMatch(lineContent);
        if (!alreadyFoundSubtotalWithValueThisLine) {
          String nextLineRaw = lines[i + 1]; // Usar raw para el chequeo de keywords
          String nextLineTrimmed = nextLineRaw.trim();

          // *** PRIMER CAMBIO IMPORTANTE APLICADO AQUÍ ***
          bool nextLineContainsOtherKeywords =
              specificIvaKeywordsForNextLineCheck.hasMatch(nextLineRaw) || // Chequea 'IVA', 'JVA', 'IMPUESTO'
                  totalKeywordRegex.hasMatch(nextLineRaw) || // Chequea 'TOTAL', 'IMPORTE', etc.
                  nextLineRaw.contains("TOTAL") || // Doble chequeo simple por si la regex no cubre
                  nextLineRaw.contains("IMPORTE");

          if (!nextLineContainsOtherKeywords) {
            Match? subtotalValueMatchNextLine = amountSimpleNumberRegex.firstMatch(nextLineTrimmed) ??
                amountCurrencyRegex.firstMatch(nextLineTrimmed);
            if (subtotalValueMatchNextLine != null &&
                subtotalValueMatchNextLine.group(1) != null) {
              String val = _cleanNumericValue(
                  subtotalValueMatchNextLine.group(1)!.replaceAll(RegExp(r'[\$€MXN\s]'), '')) ??
                  "";
              if (val.isNotEmpty) {
                potentialAmountsGeneric.add({
                  'value': val,
                  'type': 'subtotal_label_next_line',
                  'line': i + 1
                });
                print(
                    "Candidato a SUBTOTAL (etiqueta, sig. línea VALIDA): $val en línea '$nextLineTrimmed'");
              }
            }
          } else {
            print(
                "Se encontró etiqueta SUBTOTAL en línea '$lineContent', pero la siguiente línea '$nextLineRaw' parece contener keywords de IVA/Total. Se ignora como valor de subtotal directo.");
          }
        }
      }

      // Montos genéricos (sin keyword específica en esta línea, pero con formato de moneda o número simple)
      bool identifiedByKeywordThisLine = totalKeywordRegex.hasMatch(lineContent) ||
          subtotalKeywordRegex.hasMatch(lineContent) ||
          (ivaLabelRegex.hasMatch(lineContent) &&
              ivaLineMatch?.group(2) != null &&
              ivaLineMatch!.group(2)!.isNotEmpty);

      if (!identifiedByKeywordThisLine) {
        Match? genericAmountMatch = amountCurrencyRegex.firstMatch(lineContent) ??
            amountSimpleNumberRegex.firstMatch(lineContent);
        if (genericAmountMatch != null && genericAmountMatch.group(1) != null) {
          String val = _cleanNumericValue(
              genericAmountMatch.group(1)!.replaceAll(RegExp(r'[\$€MXN\s]'), '')) ??
              "";
          if (val.isNotEmpty) {
            potentialAmountsGeneric.add(
                {'value': val, 'type': 'generic_amount', 'line': i});
            print("Monto genérico detectado: $val en línea '$lineContent'");
          }
        }
      }
    }

    // --- LÓGICA DE ADJUDICACIÓN MEJORADA ---
    print("--- Iniciando Lógica de Adjudicación ---");
    print("Candidatos Genéricos Encontrados: $potentialAmountsGeneric");

    List<Map<String, dynamic>> validNumericAmounts = potentialAmountsGeneric
        .where((item) => double.tryParse(item['value']) != null)
        .map((item) => {...item, 'doubleValue': double.parse(item['value'])})
        .toList();

    // 1. IDENTIFICAR TOTAL
    var totalKeywordCandidates =
    validNumericAmounts.where((item) => item['type'] == 'total_keyword').toList();
    if (totalKeywordCandidates.isNotEmpty) {
      totalKeywordCandidates
          .sort((a, b) => (b['doubleValue'] as double).compareTo(a['doubleValue'] as double));
      foundAmount = totalKeywordCandidates.first['value'];
      print("TOTAL adjudicado (por keyword 'TOTAL'): $foundAmount");
    } else {
      if (validNumericAmounts.length >= 2) {
        validNumericAmounts
            .sort((a, b) => (b['doubleValue'] as double).compareTo(a['doubleValue'] as double));
        var potentialTotal = validNumericAmounts.firstWhere(
                (item) =>
            item['type'] != 'iva_keyword_same_line' &&
                item['type'] != 'iva_keyword_next_line' &&
                item['type'] != 'subtotal_keyword' &&
                item['type'] != 'subtotal_label_next_line',
            orElse: () =>
            validNumericAmounts.isNotEmpty ? validNumericAmounts.first : {'value': null});
        if (potentialTotal['value'] != null) {
          foundAmount = potentialTotal['value'];
          print(
              "TOTAL adjudicado (por ser el mayor de los genéricos no IVA/Subtotal): $foundAmount");
        }
      }
    }

    // 2. IDENTIFICAR IVA
    var ivaCandidates = validNumericAmounts
        .where((item) => item['type'].startsWith('iva_keyword'))
        .toList();
    if (ivaCandidates.isNotEmpty) {
      var ivaItem = ivaCandidates.firstWhere((item) => (item['doubleValue'] as double) > 0,
          orElse: () => ivaCandidates.isNotEmpty ? ivaCandidates.first : {'value': null});
      if (ivaItem['value'] != null) {
        foundIva = ivaItem['value'];
        print("IVA adjudicado (por keyword 'IVA'): $foundIva");
      }
    }

    // 3. IDENTIFICAR SUBTOTAL
    var subtotalKeywordSystemCand = validNumericAmounts
        .where((item) =>
    item['type'] == 'subtotal_keyword' ||
        item['type'] == 'subtotal_label_next_line')
        .toList();

    if (subtotalKeywordSystemCand.isNotEmpty) {
      subtotalKeywordSystemCand
          .sort((a, b) => (a['doubleValue'] as double).compareTo(b['doubleValue'] as double));
      for (var subItem in subtotalKeywordSystemCand) {
        if (foundAmount != null) {
          if ((subItem['doubleValue'] as double) <
              (double.tryParse(foundAmount!) ?? double.infinity) &&
              subItem['value'] != foundAmount &&
              subItem['value'] != foundIva) {
            foundSubtotal = subItem['value'];
            print("SUBTOTAL adjudicado (por keyword y < Total): $foundSubtotal");
            break;
          }
        } else {
          if (subItem['value'] != foundIva) {
            foundSubtotal = subItem['value'];
            print("SUBTOTAL adjudicado (por keyword, sin Total aún): $foundSubtotal");
            break;
          }
        }
      }
      if (foundSubtotal == null && subtotalKeywordSystemCand.isNotEmpty) {
        var firstValid = subtotalKeywordSystemCand.firstWhere(
                (sc) => sc['value'] != foundAmount && sc['value'] != foundIva,
            orElse: () => {'value': null});
        if (firstValid['value'] != null) {
          foundSubtotal = firstValid['value'];
          print("SUBTOTAL adjudicado (por keyword, fallback): $foundSubtotal");
        } else if (subtotalKeywordSystemCand.isNotEmpty) {
          // Último recurso de keyword de subtotal
          // Asegurarse de que no sea igual al IVA o al Total si ya están definidos
          var lastResortSub = subtotalKeywordSystemCand.firstWhere(
                  (sc) => sc['value'] != foundAmount && sc['value'] != foundIva,
              orElse: () => subtotalKeywordSystemCand.isNotEmpty
                  ? subtotalKeywordSystemCand.first
                  : {'value': null});
          if (lastResortSub['value'] != null) {
            foundSubtotal = lastResortSub['value'];
            print(
                "SUBTOTAL adjudicado (por keyword, último recurso filtrado): $foundSubtotal");
          } else if (subtotalKeywordSystemCand.isNotEmpty) {
            // Si todos eran igual a IVA/Total, tomar el primero de la lista de keywords
            foundSubtotal = subtotalKeywordSystemCand.first['value'];
            print(
                "SUBTOTAL adjudicado (por keyword, último recurso absoluto): $foundSubtotal");
          }
        }
      }
    }

    // *** SEGUNDO CAMBIO IMPORTANTE APLICADO AQUÍ ***
    // Si no hay subtotal por keyword, Y tenemos Total e IVA,
    // buscar un monto genérico que coincida con Total - IVA.
    if (foundSubtotal == null && foundAmount != null && foundIva != null) {
      double? totalD = double.tryParse(foundAmount!);
      double? ivaD = double.tryParse(foundIva!);
      if (totalD != null && ivaD != null && totalD > ivaD) {
        double expectedSubtotalVal = totalD - ivaD;
        // Ordenar los genéricos por proximidad al valor esperado puede ser útil si hay varios candidatos
        validNumericAmounts.sort((a, b) {
          if (a['type'] != 'generic_amount' || b['type'] != 'generic_amount')
            return 0;
          double diffA = ((a['doubleValue'] as double) - expectedSubtotalVal).abs();
          double diffB = ((b['doubleValue'] as double) - expectedSubtotalVal).abs();
          return diffA.compareTo(diffB);
        });

        var matchingGenericAmount = validNumericAmounts.firstWhere(
                (item) =>
            item['type'] == 'generic_amount' &&
                (item['doubleValue'] as double) > 0 &&
                (item['doubleValue'] as double) != totalD &&
                (item['doubleValue'] as double) != ivaD &&
                ((item['doubleValue'] as double) - expectedSubtotalVal).abs() <
                    0.015, // Tolerancia ligeramente aumentada
            orElse: () => {'value': null});

        if (matchingGenericAmount['value'] != null) {
          // Antes de adjudicar, asegurarnos que este valor no haya sido el origen del IVA o Total por keyword
          // Esto es para evitar que si Total-IVA = IVA (caso raro), no se confunda.
          bool isAlreadyIvaOrTotalByKeyword =
              (foundIva == matchingGenericAmount['value'] &&
                  ivaCandidates.any((ic) => ic['value'] == foundIva)) ||
                  (foundAmount == matchingGenericAmount['value'] &&
                      totalKeywordCandidates.any((tc) => tc['value'] == foundAmount));

          if (!isAlreadyIvaOrTotalByKeyword) {
            foundSubtotal = matchingGenericAmount['value'];
            print(
                "SUBTOTAL adjudicado (genérico coincidente con Total - IVA): $foundSubtotal");
          } else {
            print(
                "SUBTOTAL candidato (${matchingGenericAmount['value']}) por cálculo (Total-IVA) fue descartado porque ya era IVA/Total por keyword.");
          }
        }
      }
    }

    // 4. LÓGICA DE CÁLCULO Y AJUSTE FINAL
    double? totalD = foundAmount != null ? double.tryParse(foundAmount!) : null;
    double? subtotalD =
    foundSubtotal != null ? double.tryParse(foundSubtotal!) : null;
    double? ivaD = foundIva != null ? double.tryParse(foundIva!) : null;

    if (totalD == null && subtotalD != null && ivaD != null) {
      totalD = subtotalD + ivaD;
      foundAmount = totalD.toStringAsFixed(2);
      print("TOTAL calculado (Subtotal + IVA): $foundAmount");
    } else if (subtotalD == null && totalD != null && ivaD != null) {
      if (totalD > ivaD) {
        subtotalD = totalD - ivaD;
        foundSubtotal = subtotalD.toStringAsFixed(2);
        print("SUBTOTAL calculado (Total - IVA): $foundSubtotal");
      }
    } else if (ivaD == null && totalD != null && subtotalD != null) {
      if (totalD > subtotalD) {
        ivaD = totalD - subtotalD;
        foundIva = ivaD.toStringAsFixed(2);
        print("IVA calculado (Total - Subtotal): $foundIva");
      }
    }

    if (foundSubtotal != null &&
        foundAmount != null &&
        foundIva != null &&
        foundSubtotal == foundAmount &&
        (double.tryParse(foundIva!) ?? 0) > 0) {
      // Solo si IVA > 0
      print(
          "Advertencia: Subtotal y Total son idénticos ($foundSubtotal) con un IVA ($foundIva) > 0. Recalculando Subtotal.");
      double? tempTotal = double.tryParse(foundAmount!);
      double? tempIva = double.tryParse(foundIva!);
      if (tempTotal != null && tempIva != null && tempTotal > tempIva) {
        foundSubtotal = (tempTotal - tempIva).toStringAsFixed(2);
        print(
            "SUBTOTAL recalculado (Total - IVA) porque era igual al Total: $foundSubtotal");
      }
    }

    if (foundAmount == null ||
        (totalKeywordCandidates.isEmpty && foundSubtotal != null && foundIva != null)) {
      double? sD = foundSubtotal != null ? double.tryParse(foundSubtotal!) : null;
      double? iD = foundIva != null ? double.tryParse(foundIva!) : null;
      if (sD != null &&
          iD != null &&
          (sD + iD) >
              (double.tryParse(foundAmount ?? "0") ??
                  0)) {
        // Solo si la suma es mayor que el total encontrado (o si no hay total)
        foundAmount = (sD + iD).toStringAsFixed(2);
        print("TOTAL recalculado/establecido como (Subtotal + IVA): $foundAmount");
      }
    }

    _initialDate = foundDate?.isNotEmpty == true ? foundDate : null;
    _initialLiters =
    _cleanNumericValue(foundLiters)?.isNotEmpty == true ? _cleanNumericValue(foundLiters) : null;
    _initialSubtotal = _cleanNumericValue(foundSubtotal)?.isNotEmpty == true
        ? _cleanNumericValue(foundSubtotal)
        : null;
    _initialIva =
    _cleanNumericValue(foundIva)?.isNotEmpty == true ? _cleanNumericValue(foundIva) : null;
    _initialAmount = _cleanNumericValue(foundAmount)?.isNotEmpty == true
        ? _cleanNumericValue(foundAmount)
        : null;
    _initialVehiclePlate =
    foundVehiclePlate?.isNotEmpty == true ? foundVehiclePlate : null;

    print(
        "Datos Parseados Finales: Fecha='$_initialDate', Litros='$_initialLiters', Subtotal='$_initialSubtotal', IVA='$_initialIva', Total='$_initialAmount', Placa='$_initialVehiclePlate'");
  }
// END: _parseTicketData

// END: _parseTicketData

  // END: _parseTicketData

  Future<void> _performTextRecognitionAndParse() async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });

    File? tempResizedImage;

    try {
      print(
          "Imagen original para procesar: ${widget.imageFile.path} (Tamaño: ${await widget.imageFile.length()} bytes)");
      File imageToProcess =
      await _getResizedImage(widget.imageFile, maxWidth: 1280, quality: 85);
      if (imageToProcess.path != widget.imageFile.path) {
        tempResizedImage = imageToProcess;
      }

      final inputImage = InputImage.fromFile(imageToProcess);
      print("Iniciando procesamiento con ML Kit...");
      final RecognizedText recognizedText =
      await _textRecognizer.processImage(inputImage);
      print("ML Kit procesó la imagen.");
      if (!mounted) return;

      setState(() {
        _fullRecognizedText = recognizedText.text;
      });

      _parseTicketData(recognizedText.text); // LLAMADA A LA FUNCIÓN ACTUALIZADA

    } catch (e) {
      if (!mounted) return;
      final String errorMessage = 'Error al procesar la imagen: $e';
      print(errorMessage);
      setState(() {
        _fullRecognizedText =
        "Error procesando: ${e.toString().substring(0, (e.toString().length > 150) ? 150 : e.toString().length)}...";
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en ML Kit: ${e.toString()}')),
        );
        final notificationProvider =
        Provider.of<NotificationProvider>(context, listen: false);
        notificationProvider.addNotification(
          'Error en OCR',
          'No pudimos procesar la imagen del ticket. Detalles: ${e.toString().substring(0, (e.toString().length > 100) ? 100 : e.toString().length)}...',
        );
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _dateController.text = _initialDate ?? '';
        _litersController.text = _initialLiters ?? '';
        _subtotalController.text = _initialSubtotal ?? ''; // Nuevo
        _ivaController.text = _initialIva ?? ''; // Nuevo
        _amountController.text = _initialAmount ?? ''; // Total
        _vehiclePlateController.text = _initialVehiclePlate ?? '';
      });

      if (tempResizedImage != null) {
        try {
          await tempResizedImage.delete();
          print(
              "Imagen temporal redimensionada (${tempResizedImage.path}) eliminada.");
        } catch (e) {
          print("Error al eliminar imagen temporal redimensionada: $e");
        }
      }
    }
  }

  String? _cleanNumericValue(String? value) {
    if (value == null || value.isEmpty) return null;
    String cleaned = value.replaceAll(',', '.'); // Comas a puntos para decimales
    cleaned =
        cleaned.replaceAll(RegExp(r'[^\d\.]'), ''); // Quitar no dígitos excepto punto

    // Evitar múltiples puntos decimales o puntos al final sin números después
    final parts = cleaned.split('.');
    if (parts.length > 2) {
      // Más de un punto decimal "1.2.3" -> "1.23"
      cleaned = '${parts[0]}.${parts.sublist(1).join('')}';
    } else if (parts.length == 2 && parts[1].isEmpty && cleaned.endsWith('.')) {
      // Si es como "123." (termina en punto pero es entero)
      cleaned = parts[0];
    } else if (parts.length == 1 && cleaned.endsWith('.')) {
      // Caso "123." que no fue dividido por split (es un entero con punto al final)
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    // Asegurar que solo haya un punto si es decimal y no al inicio sin un cero
    if (cleaned.startsWith('.')) cleaned = '0$cleaned'; // ej: ".5" -> "0.5"

    // Una última verificación para múltiples puntos que pudieron quedar
    if (cleaned.split('.').length > 2) {
      final firstDotIndex = cleaned.indexOf('.');
      if (firstDotIndex != -1) {
        // Asegurarse que haya un punto
        cleaned = cleaned.substring(0, firstDotIndex + 1) +
            cleaned.substring(firstDotIndex + 1).replaceAll('.', '');
      }
    }

    return cleaned.isEmpty ? null : cleaned;
  }

// ... (CÓDIGO DE LA PARTE 1 TERMINA AQUÍ, CON _cleanNumericValue)

  Future<String?> _uploadTicketImage(File imageFile, String userId) async {
    File fileToUpload = widget.imageFile; // Usar la imagen original para subir
    print("--- Iniciando _uploadTicketImage ---");
    print("UserID para la subida: $userId");
    print("Ruta del archivo a subir: ${fileToUpload.path}");
    print("Tamaño del archivo a subir: ${await fileToUpload.length()} bytes");

    try {
      bool fileExists = await fileToUpload.exists();
      print("El archivo a subir existe: $fileExists");
      if (!fileExists) {
        print(
            "¡ERROR CRÍTICO! El archivo de imagen no existe en la ruta especificada antes de la subida.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Error interno: El archivo de imagen no se encontró para subir.')),
          );
        }
        return null;
      }

      String fileName =
          'tickets/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print("Nombre de archivo en Storage: $fileName");
      Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      print("Referencia de Storage creada: ${storageRef.fullPath}");
      print("Iniciando storageRef.putFile()...");
      UploadTask uploadTask = storageRef.putFile(
          fileToUpload, SettableMetadata(contentType: 'image/jpeg'));

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            'Evento de subida: ${snapshot.state}, Progreso: ${(snapshot.bytesTransferred / snapshot.totalBytes) * 100}%');
      }, onError: (Object e, StackTrace stackTrace) {
        print("Error durante el stream de subida de Firebase Storage: $e");
        print("StackTrace del error de stream: $stackTrace");
      });

      print("Esperando a que se complete la subida (await uploadTask)...");
      TaskSnapshot snapshot = await uploadTask;
      print("Subida completada. Estado: ${snapshot.state}");
      print("Intentando obtener URL de descarga...");
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Imagen subida exitosamente: $downloadUrl");
      print("--- Finalizando _uploadTicketImage exitosamente ---");
      return downloadUrl;
    } on FirebaseException catch (e) {
      print("FirebaseException al subir la imagen a Firebase Storage: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Error de Firebase al subir imagen: ${e.message} (Código: ${e.code})')),
        );
      }
      return null;
    } catch (e, stackTrace) {
      print("Error genérico al subir la imagen a Firebase Storage: $e");
      print("StackTrace: $stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error desconocido al subir la imagen: ${e.toString()}')),
        );
      }
      return null;
    }
  }

  Future<void> _saveTicketData() async {
    final String dateStr = _dateController.text.trim();
    final String litersStr = _litersController.text.trim();
    final String subtotalStr = _subtotalController.text.trim(); // Nuevo
    final String ivaStr = _ivaController.text.trim(); // Nuevo
    final String amountStr = _amountController.text.trim(); // Total
    final String vehiclePlateStr =
    _vehiclePlateController.text.trim().toUpperCase();

    if (dateStr.isEmpty ||
        litersStr.isEmpty ||
        subtotalStr.isEmpty || // Nuevo
        ivaStr.isEmpty || // Nuevo
        amountStr.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, completa todos los campos requeridos.'),
            backgroundColor: colorError),
      );
      return;
    }

    final double? liters = double.tryParse(litersStr);
    final double? subtotal = double.tryParse(subtotalStr); // Nuevo
    final double? iva = double.tryParse(ivaStr); // Nuevo
    final double? amount = double.tryParse(amountStr); // Total

    if (liters == null ||
        liters <= 0 ||
        subtotal == null || // Nuevo
        subtotal < 0 || // Puede ser 0 si no hay subtotal separado
        iva == null || // Nuevo
        iva < 0 || // Puede ser 0 si no hay IVA
        amount == null ||
        amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Por favor, ingresa valores numéricos válidos y positivos para los montos y litros.'),
            backgroundColor: colorError),
      );
      return;
    }

    DateTime? parsedDate;
    try {
      parsedDate = DateFormat('dd/MM/yyyy').parse(dateStr);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Formato de fecha inválido. Usa DD/MM/AAAA.'),
            backgroundColor: colorError),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay usuario autenticado.'),
            backgroundColor: colorError),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String? imageUrl;
    try {
      imageUrl = await _uploadTicketImage(widget.imageFile, user.uid);
      if (imageUrl == null) {
        throw Exception('No se pudo subir la imagen del ticket.');
      }
    } catch (e) {
      print("Error al subir imagen antes de guardar ticket: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al subir la imagen del ticket: ${e.toString()}'),
            backgroundColor: colorError),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('tickets').add({
        'userId': user.uid,
        'liters': liters,
        'amount': amount,
        'subtotal': subtotal, // Nuevo
        'iva': iva, // Nuevo
        'vehiclePlate': vehiclePlateStr.isEmpty ? 'N/A' : vehiclePlateStr,
        'dateTimestamp': Timestamp.fromDate(parsedDate),
        'dateString': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
        'imageUrl': imageUrl,
        'status': 'Pendiente', // Estado inicial
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('Ticket guardado exitosamente.'),
            backgroundColor: azulClaroApp),
      );

      final notificationProvider =
      Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.addNotification(
        'Ticket Guardado Exitosamente',
        'Tu ticket del ${DateFormat('dd/MM/yyyy').format(parsedDate)} por \$$amount ha sido registrado. Estado: Pendiente.',
      );

      Navigator.pushNamedAndRemoveUntil(
          context, '/ticket_confirmation', (route) => false);
    } catch (e) {
      print("Error al guardar ticket en Firestore: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error al guardar el ticket: ${e.toString()}'),
            backgroundColor: colorError),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    DateTime initialDate;
    try {
      initialDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    } catch (e) {
      initialDate = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: azulPrincipalApp, // Color principal del DatePicker
              onPrimary: colorTextoBlanco, // Color del texto en el encabezado
              surface: Colors.white, // Fondo del calendario
              onSurface: colorTextoPrincipal, // Color de los días
            ),
            dialogBackgroundColor: Colors.white,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: azulPrincipalApp, // Color de los botones OK/CANCEL
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
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
  void dispose() {
    _textRecognizer.close();
    _dateController.dispose();
    _litersController.dispose();
    _subtotalController.dispose();
    _ivaController.dispose();
    _amountController.dispose();
    _vehiclePlateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorFondoScaffold,
      appBar: AppBar(
        title: const Text(
          'Validar Ticket',
          style: TextStyle(color: azulPrincipalApp, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: azulPrincipalApp),
      ),
      body: _isProcessing
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: azulPrincipalApp),
            const SizedBox(height: 20),
            Text('Procesando imagen...',
                style: TextStyle(color: azulPrincipalApp, fontSize: 16)),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Revisa y corrige los datos:',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: azulPrincipalApp.withOpacity(0.9)),
            ),
            const SizedBox(height: 24),

            // Fecha de Carga
            TextFormField(
              controller: _dateController,
              decoration: _inputDecoration(
                  'Fecha de Carga', 'DD/MM/AAAA', Icons.calendar_today_outlined),
              readOnly: true,
              onTap: () => _pickDate(context),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 16.0),

            // Litros Cargados
            TextFormField(
              controller: _litersController,
              decoration: _inputDecoration(
                  'Litros Cargados', 'Ej: 45.50', Icons.local_gas_station_outlined),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16.0),

            // Subtotal
            TextFormField(
              controller: _subtotalController,
              decoration: _inputDecoration(
                  'Subtotal (\$)', 'Ej: 750.00', Icons.attach_money_outlined),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16.0),

            // IVA
            TextFormField(
              controller: _ivaController,
              decoration: _inputDecoration(
                  'IVA (\$)', 'Ej: 100.00', Icons.attach_money_outlined),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16.0),

            // Monto Total
            TextFormField(
              controller: _amountController,
              decoration: _inputDecoration(
                  'Monto Total (\$)', 'Ej: 850.00', Icons.price_change_outlined),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16.0),

            // Placa del Vehículo
            TextFormField(
              controller: _vehiclePlateController,
              decoration: _inputDecoration(
                  'Placa del Vehículo (Opcional)', 'Ej: ABC1234', Icons.car_repair_outlined),
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
            ),
            const SizedBox(height: 30.0),

            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveTicketData,
              icon: _isSaving
                  ? Container(
                  width: 20,
                  height: 20,
                  child: const CircularProgressIndicator(
                      strokeWidth: 2, color: colorTextoBlanco))
                  : const Icon(Icons.check_circle_outline,
                  color: colorTextoBlanco),
              label: Text(
                _isSaving ? 'Guardando Ticket...' : 'Guardar Ticket',
                style: const TextStyle(color: colorTextoBlanco),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: azulPrincipalApp,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
            const SizedBox(height: 16.0),
            OutlinedButton.icon(
              onPressed: _isSaving
                  ? null
                  : () {
                Navigator.pop(context); // Volver a la pantalla anterior
              },
              icon: Icon(Icons.cancel_outlined, color: azulClaroApp),
              label: Text('Cancelar',
                  style: TextStyle(color: azulClaroApp)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                side: BorderSide(color: azulClaroApp, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Texto Completo Reconocido:',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: azulPrincipalApp),
            ),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              height: 200, // Altura fija para el texto reconocido
              child: SingleChildScrollView(
                child: Text(
                  _fullRecognizedText.isEmpty
                      ? 'No se detectó texto o hubo un error.'
                      : _fullRecognizedText,
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}