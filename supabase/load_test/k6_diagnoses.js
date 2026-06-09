import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const BASE_URL = __ENV.SUPABASE_URL || 'https://your-project.supabase.co';
const SERVICE_KEY = __ENV.SUPABASE_SERVICE_KEY || '';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '30s', target: 100 },
    { duration: '1m', target: 500 },
    { duration: '30s', target: 1000 },
    { duration: '2m', target: 1000 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.05'],
    errors: ['rate<0.1'],
  },
};

const headers = {
  'apikey': SERVICE_KEY,
  'Authorization': `Bearer ${SERVICE_KEY}`,
  'Content-Type': 'application/json',
};

export default () => {
  const diagnosisPayload = JSON.stringify({
    user_id: 'test-user-id',
    crop_id: 'cassava',
    model_version: 'cassava-v1.0.0',
    image_path: 'test/test.jpg',
    predicted_disease_id: 'cassava_green_mottle',
    confidence: 0.85,
    top_k_predictions: [
      { label: 'cassava_green_mottle', confidence: 0.85 },
      { label: 'cassava_brown_streak', confidence: 0.10 },
    ],
  });

  const start = Date.now();

  const res = http.post(
    `${BASE_URL}/rest/v1/diagnoses`,
    diagnosisPayload,
    { headers }
  );

  const duration = Date.now() - start;

  check(res, {
    'status is 201 or 400': (r) => r.status === 201 || r.status === 400,
    'response time < 500ms': () => duration < 500,
  }) || errorRate.add(1);

  sleep(1);
}