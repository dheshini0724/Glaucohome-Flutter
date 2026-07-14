// lib/screens/research_screen.dart

import 'package:flutter/material.dart';

class ResearchScreen extends StatelessWidget {
  const ResearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        title: const Text('Research & Reference'),
        backgroundColor: const Color(0xFF0B1120),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('ACD Clinical Reference'),
            const SizedBox(height: 12),
            _acdTable(),
            const SizedBox(height: 28),
            _sectionHeader('What is ACD?'),
            const SizedBox(height: 10),
            _infoCard(
              'Anterior Chamber Depth (ACD) is the distance from the posterior '
              'surface of the cornea to the anterior surface of the crystalline '
              'lens. A shallow ACD is a critical risk factor for angle-closure glaucoma.',
            ),
            const SizedBox(height: 20),
            _sectionHeader('Our Measurement Method'),
            const SizedBox(height: 10),
            _stepCard(const [
              ('1', 'Rear camera + flash captures a high-contrast eye image.'),
              (
                '2',
                'OpenCV detects corneal boundary (outer) and pupil (inner) using Hough Circle Transform.'
              ),
              (
                '3',
                'Euclidean distance between the two circle centres is computed in pixels.'
              ),
              (
                '4',
                'Pixels → mm conversion using average corneal diameter (11.7 mm) as scale reference.'
              ),
              ('5', 'ACD value is classified against clinical thresholds.'),
            ]),
            const SizedBox(height: 28),
            _sectionHeader('Glaucoma Risk Classification'),
            const SizedBox(height: 12),
            _riskTable(),
            const SizedBox(height: 28),
            _sectionHeader('Key Facts'),
            const SizedBox(height: 12),
            _factsList(const [
              'Glaucoma is the leading cause of irreversible blindness worldwide.',
              'Angle-closure glaucoma causes ~50% of glaucoma blindness despite being less prevalent.',
              'Shallow ACD (< 2.5 mm) raises resistance to aqueous humour drainage, increasing IOP.',
              'Average adult ACD: 3.15 mm; decreases with age.',
              'Early ACD screening can prevent acute angle-closure attacks.',
              'Gold-standard tools: Pentacam, IOLMaster, A-scan ultrasonography.',
            ]),
            const SizedBox(height: 28),
            _sectionHeader('References'),
            const SizedBox(height: 10),
            _infoCard(
              '• Lowe RF. Anterior lens displacement with age. Br J Ophthalmol. 1970.\n'
              '• Lavanya R et al. Screening for narrow angles in Singapore. Ophthalmology. 2008.\n'
              '• WHO. Global Data on Visual Impairment. 2020.',
              mono: true,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Reusable builders ─────────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF38C5E0),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
      ],
    );
  }

  Widget _infoCard(String content, {bool mono = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112233),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(content,
          style: TextStyle(
              color: Colors.white70,
              height: 1.6,
              fontSize: 13,
              fontFamily: mono ? 'monospace' : null)),
    );
  }

  Widget _acdTable() {
    const headers = ['ACD (mm)', 'Classification', 'Risk'];
    const rows = [
      ['< 2.0', 'Critically Shallow', 'High'],
      ['2.0 – 2.5', 'Shallow', 'Borderline'],
      ['2.5 – 4.5', 'Normal', 'Low'],
      ['> 4.5', 'Deep', 'Evaluate'],
    ];
    const colors = [
      Color(0xFFE74C3C),
      Color(0xFFF39C12),
      Color(0xFF2ECC71),
      Color(0xFF5B8CFF),
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF112233),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0A2240),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: headers
                  .map((h) => Expanded(
                        child: Text(h,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFF38C5E0),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ))
                  .toList(),
            ),
          ),
          ...rows.asMap().entries.map((e) {
            final i = e.key;
            final row = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.06))),
              ),
              child: Row(
                children: [
                  Expanded(
                      child: Text(row[0],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors[i],
                              fontWeight: FontWeight.w600,
                              fontSize: 13))),
                  Expanded(
                      child: Text(row[1],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12))),
                  Expanded(
                      child: Text(row[2],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: colors[i],
                              fontWeight: FontWeight.bold,
                              fontSize: 12))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _riskTable() {
    const items = [
      (
        'Normal',
        '2.5–4.5 mm',
        'Low risk. Aqueous drainage angle is open.',
        Color(0xFF2ECC71)
      ),
      (
        'Borderline',
        '2.0–2.5 mm',
        'Moderate risk. Consider prophylactic iridotomy evaluation.',
        Color(0xFFF39C12)
      ),
      (
        'High Risk',
        '< 2.0 mm',
        'High risk for angle-closure glaucoma. Urgent referral.',
        Color(0xFFE74C3C)
      ),
      (
        'Deep Chamber',
        '> 4.5 mm',
        'Unusual depth. May indicate myopia or lens subluxation.',
        Color(0xFF5B8CFF)
      ),
    ];

    return Column(
      children: items
          .map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: item.$4.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: item.$4.withOpacity(0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 3),
                      decoration:
                          BoxDecoration(color: item.$4, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(item.$1,
                                style: TextStyle(
                                    color: item.$4,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(width: 8),
                            Text(item.$2,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                          ]),
                          const SizedBox(height: 4),
                          Text(item.$3,
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  Widget _stepCard(List<(String, String)> steps) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF112233),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: steps
            .map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF38C5E0).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(s.$1,
                            style: const TextStyle(
                                color: Color(0xFF38C5E0),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.$2,
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.5)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _factsList(List<String> facts) {
    return Column(
      children: facts
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ',
                        style: TextStyle(
                            color: Color(0xFF38C5E0),
                            fontSize: 14,
                            fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(f,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.5)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
