import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        title: const Row(
          children: [
            Text('❓', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Guide de l\'application',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HelpSection(
            emoji: '🤖',
            title: 'Assistant IA — Accueil',
            color: Color(0xFF2E86AB),
            items: [
              'Appuyez sur une option dans le chat pour interagir',
              'Choisissez "Réserver un terrain" pour réserver',
              'Choisissez "Match" pour rejoindre ou créer un match',
              'Bouton 🔄 Réinitialiser en bas pour recommencer la conversation',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '🏟️',
            title: 'Réservation de terrain',
            color: Color(0xFF27AE60),
            items: [
              'Sélectionnez le type de terrain : Couvert ☀️ ou Extérieur 🏠',
              'Choisissez une date disponible',
              'Seuls les créneaux avec des terrains libres sont affichés',
              'Confirmez votre réservation — vous recevrez une notification WhatsApp',
              'Retrouvez vos réservations dans l\'onglet 📋 Réservations',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '⚡',
            title: 'Matchs',
            color: Color(0xFFE74C3C),
            items: [
              'Rejoindre un match : trouvez un match ouvert par niveau',
              'Créer un match : basé sur une de vos réservations',
              'Définissez le nombre de joueurs max (2 ou 4) et le niveau',
              'Le prix est divisé automatiquement entre les joueurs',
              'Le match se ferme quand il est complet',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '📊',
            title: 'Classement ELO',
            color: Color(0xFF9B59B6),
            items: [
              'Chaque joueur commence à 1000 points ELO',
              'Après un match : déclarez le résultat via votre profil',
              'Le résultat doit être confirmé par un joueur de l\'équipe adverse',
              'Gagner contre un joueur plus fort = plus de points',
              'Tiers : 🥉 Bronze · 🥈 Argent · 🥇 Or · 💎 Platine · 👑 Diamant',
              'Consultez le classement via 🏆 dans la barre du haut',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '💰',
            title: 'Wallet (Portefeuille)',
            color: Color(0xFFF39C12),
            items: [
              'Rechargez votre wallet depuis votre profil',
              'Payez vos réservations et matchs directement',
              'Historique des transactions disponible',
              'Les remboursements sont automatiques en cas d\'annulation',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '👥',
            title: 'Joueurs & Amis',
            color: Color(0xFF1ABC9C),
            items: [
              'Recherchez des joueurs dans l\'onglet Matchs',
              'Ajoutez des amis depuis leur profil',
              'Envoyez des messages via l\'onglet 💬 Chat',
              'Bloquez un joueur si nécessaire (menu ⋮ sur son profil)',
              'Notez vos partenaires après un match',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '🔔',
            title: 'Notifications',
            color: Color(0xFF34495E),
            items: [
              'Notifications in-app : cloche 🔔 en haut à droite',
              'WhatsApp : activé si votre numéro est renseigné',
              'Types : réservation confirmée, match rejoint, ELO mis à jour',
              'Toutes les notifications sont marquées lues automatiquement',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '🏆',
            title: 'Tournois & Marché',
            color: Color(0xFFE67E22),
            items: [
              'Onglet Tournois : consultez et inscrivez-vous aux tournois du club',
              'Onglet Marché : achetez et vendez équipements de padel',
              'Ces fonctionnalités sont gérées par l\'administration du club',
            ],
          ),
          SizedBox(height: 12),
          _HelpSection(
            emoji: '⚙️',
            title: 'Mon Profil',
            color: Color(0xFF7F8C8D),
            items: [
              'Modifiez votre nom, avatar et niveau via ✏️',
              'Changez la langue : Français 🇫🇷 · English 🇬🇧 · العربية 🇸🇦',
              'Déconnectez-vous en bas de votre profil',
              'Votre niveau (1–8) est différent de votre ELO : le niveau est auto-déclaré',
            ],
          ),
          SizedBox(height: 24),
          _ContactCard(),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String emoji;
  final String title;
  final Color color;
  final List<String> items;

  const _HelpSection({
    required this.emoji,
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child:
                          Text(emoji, style: const TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: color),
                ),
              ],
            ),
          ),
          // Items
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              children: items
                  .map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 6, right: 8),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Text('🎾', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text(
            'Padel Club',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          SizedBox(height: 4),
          Text(
            'Pour toute aide, contactez l\'administration du club\nou signalez un problème depuis votre profil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
