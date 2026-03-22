import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import '../../services/location_service.dart';

class MyAddressesScreen extends StatefulWidget {
  const MyAddressesScreen({super.key});

  @override
  State<MyAddressesScreen> createState() => _MyAddressesScreenState();
}

class _MyAddressesScreenState extends State<MyAddressesScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _locationService = LocationService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _addresses = [];
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _db
          .collection('adresses')
          .where('idUtilisateur', isEqualTo: _userId)
          .get();
      setState(() {
        _addresses = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (e) {
      debugPrint('Error fetching addresses: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      await _db.collection('adresses').doc(addressId).delete();
      _fetchAddresses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adresse supprimée.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAddAddressSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddAddressSheet(
        userId: _userId!,
        locationService: _locationService,
        onAddressAdded: () {
          Navigator.pop(context);
          _fetchAddresses();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Mes Adresses', style: TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A237E)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _addresses.isEmpty
              ? const Center(child: Text('Aucune adresse trouvée.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _addresses.length,
                  itemBuilder: (context, index) {
                    final addr = _addresses[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      color: Colors.white,
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EAF6),
                          child: Icon(Icons.location_on, color: Color(0xFF3F64B5)),
                        ),
                        title: Text(addr['Quartier'] ?? 'Adresse sans quartier', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                        subtitle: Text('${addr['Rue'] ?? ''}\n${addr['Ville'] ?? ''}, ${addr['Pays'] ?? ''}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteAddress(addr['id']),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAddressSheet,
        backgroundColor: const Color(0xFF3F64B5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  final String userId;
  final LocationService locationService;
  final VoidCallback onAddressAdded;

  const _AddAddressSheet({
    required this.userId,
    required this.locationService,
    required this.onAddressAdded,
  });

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _rueCtrl = TextEditingController();
  final _batCtrl = TextEditingController();
  final _quartierCtrl = TextEditingController();
  final _villeCtrl = TextEditingController();
  final _cpCtrl = TextEditingController();
  final _paysCtrl = TextEditingController(text: 'Maroc');
  GeoPoint? _detectedGeoPoint;
  bool _isLoading = false;

  Future<void> _detectLoc() async {
    setState(() => _isLoading = true);
    try {
      final pos = await widget.locationService.getCurrentPosition();
      if (pos == null) throw Exception('Impossible de détecter la localisation.');
      setState(() => _detectedGeoPoint = GeoPoint(pos.latitude, pos.longitude));
      
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            // We only fill reliable information. We don't touch _batCtrl.
            if (p.street != null && p.street!.isNotEmpty) _rueCtrl.text = p.street!;
            
            if (p.subLocality != null && p.subLocality!.isNotEmpty) {
              _quartierCtrl.text = p.subLocality!;
            } else if (p.locality != null && p.locality!.isNotEmpty) {
               _quartierCtrl.text = p.locality!;
            }
            
            if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
              _villeCtrl.text = p.administrativeArea!;
            } else if (p.locality != null && p.locality!.isNotEmpty) {
              _villeCtrl.text = p.locality!;
            }
            
            if (p.postalCode != null && p.postalCode!.isNotEmpty) _cpCtrl.text = p.postalCode!;
            if (p.country != null && p.country!.isNotEmpty) _paysCtrl.text = p.country!;
          });
        }
      } catch (_) {
        // Fallback gracefully (GPS coordinates are already saved)
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position GPS détectée avec succès !'),
          backgroundColor: Colors.green,
        ));
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_villeCtrl.text.isEmpty || _quartierCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ville et Quartier obligatoires.')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      GeoPoint? finalGeo = _detectedGeoPoint;
      if (finalGeo == null) {
        try {
          final locs = await locationFromAddress('${_batCtrl.text} ${_rueCtrl.text}, ${_quartierCtrl.text}, ${_villeCtrl.text}');
          if (locs.isNotEmpty) {
            finalGeo = GeoPoint(locs.first.latitude, locs.first.longitude);
          }
        } catch (_) {}
      }

      await FirebaseFirestore.instance.collection('adresses').add({
        'idUtilisateur': widget.userId,
        'Rue': _rueCtrl.text.trim(),
        'NumBatiment': _batCtrl.text.trim(),
        'Quartier': _quartierCtrl.text.trim(),
        'Ville': _villeCtrl.text.trim(),
        'CodePostal': _cpCtrl.text.trim(),
        'Pays': _paysCtrl.text.trim(),
        'location': finalGeo,
      });

      // Update master location in user document
      if (finalGeo != null) {
        await FirebaseFirestore.instance.collection('utilisateurs').doc(widget.userId).update({
          'location': finalGeo,
        });
      }

      widget.onAddressAdded();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20, right: 20, top: 20,
      ),
      child: SingleChildScrollView(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           crossAxisAlignment: CrossAxisAlignment.stretch,
           children: [
             const Text('Ajouter une adresse', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
             const SizedBox(height: 16),
             OutlinedButton.icon(
               onPressed: _isLoading ? null : _detectLoc,
               icon: const Icon(Icons.my_location),
               label: const Text('Détecter ma position'),
               style: OutlinedButton.styleFrom(
                 foregroundColor: const Color(0xFF3F64B5),
                 side: const BorderSide(color: Color(0xFF3F64B5)),
                 padding: const EdgeInsets.symmetric(vertical: 12),
               ),
             ),
             const SizedBox(height: 16),
             TextField(controller: _batCtrl, decoration: const InputDecoration(labelText: 'Bâtiment / Appt')),
             TextField(controller: _rueCtrl, decoration: const InputDecoration(labelText: 'Rue')),
             TextField(controller: _quartierCtrl, decoration: const InputDecoration(labelText: 'Quartier *')),
             TextField(controller: _villeCtrl, decoration: const InputDecoration(labelText: 'Ville *')),
             TextField(controller: _cpCtrl, decoration: const InputDecoration(labelText: 'Code Postal')),
             TextField(controller: _paysCtrl, decoration: const InputDecoration(labelText: 'Pays')),
             const SizedBox(height: 16),
             if (_detectedGeoPoint != null) ...[
               const Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(Icons.check_circle, color: Colors.green, size: 16),
                   SizedBox(width: 6),
                   Text('Coordonnées GPS enregistrées', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                 ]
               ),
               const SizedBox(height: 12),
             ],
             ElevatedButton(
               onPressed: _isLoading ? null : _save,
               style: ElevatedButton.styleFrom(
                 backgroundColor: const Color(0xFF3F64B5),
                 foregroundColor: Colors.white,
                 padding: const EdgeInsets.symmetric(vertical: 14),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
               ),
               child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Enregistrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
             ),
             const SizedBox(height: 24),
           ],
         ),
      ),
    );
  }
}
