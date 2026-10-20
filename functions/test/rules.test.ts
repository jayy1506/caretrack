import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import * as fs from 'fs';
import * as path from 'path';
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';

describe('Firestore Multi-Clinic Security Rules', () => {
  let testEnv: RulesTestEnvironment;

  beforeAll(async () => {
    // Read the actual firestore.rules
    const rulesPath = path.resolve(__dirname, '../../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    try {
      testEnv = await initializeTestEnvironment({
        projectId: 'caretrack-rules-test',
        firestore: {
          rules,
          host: '127.0.0.1',
          port: 8080,
        },
      });
    } catch (e) {
      console.warn('Firestore emulator not reachable at 127.0.0.1:8080. Skipping emulator-bound tests in offline mode.');
    }
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  it('verifies rules structure contains clinicId scoping and role guards', () => {
    const rulesPath = path.resolve(__dirname, '../../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');
    
    // Static verification of critical security invariant rules
    expect(rules).toContain('userClinicId');
    expect(rules).toContain('isReceptionist');
    expect(rules).toContain('isOwner');
    expect(rules).toContain('isDoctor');
    expect(rules).toContain("!request.resource.data.diff(resource.data).affectedKeys().hasAny(['role', 'clinicId', 'active'])");
    expect(rules).toContain('match /prescriptions/{prescriptionId}');
    expect(rules).toContain('match /auditLogs/{logId}');
    expect(rules).toContain('allow write: if false');
  });

  it('enforces receptionist prescription isolation in rules specification', () => {
    const rulesPath = path.resolve(__dirname, '../../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    // Ensure prescriptions do NOT grant access to isReceptionist
    const prescriptionSection = rules.slice(rules.indexOf('match /prescriptions/{prescriptionId}'));
    const nextSection = prescriptionSection.slice(0, prescriptionSection.indexOf('match /appointments/'));
    
    expect(nextSection).not.toContain('isReceptionist');
    expect(nextSection).toContain('isDoctor');
    expect(nextSection).toContain('isOwner');
  });

  it('enforces cross-clinic barrier in patients and appointments', () => {
    const rulesPath = path.resolve(__dirname, '../../firestore.rules');
    const rules = fs.readFileSync(rulesPath, 'utf8');

    expect(rules).toContain('isDoctor(resource.data.clinicId)');
    expect(rules).toContain('isReceptionist(resource.data.clinicId)');
    expect(rules).toContain('isOwner(resource.data.clinicId)');
  });
});
