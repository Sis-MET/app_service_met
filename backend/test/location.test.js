'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { loadSupportSchemas } = require('../src/schema');
const {
  locationsByIndex,
  normalizeLocation,
  summaryLocationSql,
} = require('../src/location');
const calibration = require('../src/calibration-service');
const support = require('../src/support-service');

test('normaliza la ubicación del teléfono con 6 decimales y la fecha del fijado', () => {
  const location = normalizeLocation({
    latitud: -16.5000123456,
    longitud: '-68,1500987',
    precision_gps: 12.34,
    fecha_gps: '2026-10-15T09:30:00.000-04:00',
  });

  assert.equal(location.latitud, -16.500012);
  assert.equal(location.longitud, -68.150099);
  assert.equal(location.precisionGps, 12.3);
  assert.equal(location.fechaGps.toISOString(), '2026-10-15T13:30:00.000Z');
});

test('descarta ubicaciones incompletas, fuera de rango o sin fijado real', () => {
  assert.equal(normalizeLocation(null), null);
  assert.equal(normalizeLocation([]), null);
  assert.equal(normalizeLocation({ latitud: -16.5 }), null);
  assert.equal(normalizeLocation({ latitud: 91, longitud: 0 }), null);
  assert.equal(normalizeLocation({ latitud: 10, longitud: -181 }), null);
  assert.equal(normalizeLocation({ latitud: 0, longitud: 0 }), null);
  assert.equal(normalizeLocation({ latitud: 'abc', longitud: 1 }), null);
});

test('una precisión o fecha inválida no descarta las coordenadas', () => {
  const location = normalizeLocation({
    latitud: -17.78,
    longitud: -63.18,
    precision_gps: -4,
    fecha_gps: 'ayer',
  });
  assert.equal(location.latitud, -17.78);
  assert.equal(location.precisionGps, null);
  assert.equal(location.fechaGps, null);
});

test('las ubicaciones de calibración se alinean con el índice del registro', () => {
  const locations = locationsByIndex(
    [{ latitud: -16.5, longitud: -68.15 }, null],
    3,
  );
  assert.equal(locations.length, 3);
  assert.equal(locations[0].latitud, -16.5);
  assert.equal(locations[1], null);
  assert.equal(locations[2], null);
  assert.deepEqual(locationsByIndex(undefined, 2), [null, null]);
});

test('el resumen agrega las columnas de ubicación solo si existen', () => {
  assert.deepEqual(summaryLocationSql(false), { columns: '', values: '' });
  for (const build of [
    calibration.buildSummaryInsertQuery,
    support.buildSummaryInsertQuery,
  ]) {
    const without = build();
    assert.doesNotMatch(without, /latitud/);

    const withLocation = build(true);
    assert.match(
      withLocation,
      /\[tipo_servicio\], \[latitud\], \[longitud\], \[precision_gps\], \[fecha_gps\]\)/,
    );
    assert.match(withLocation, /@latitud, @longitud, @precisionGps, @fechaGps\)/);
    // n es IDENTITY: nunca va en la lista de columnas.
    assert.match(withLocation, /\(\[codigo_registro\], /);
  }
});

test('la ubicación de soporte viaja aparte y no entra al detalle', () => {
  const result = support.validateSupportRecords(
    [{
      module: 'mnt_prv_regular',
      data: {
        otst: 'OTST-GPS',
        cod_metrica: 'MET-GPS',
        estado_servicio: 'Completo',
      },
      ubicacion: { latitud: -16.5, longitud: -68.15, precision_gps: 8 },
    }, {
      module: 'mnt_prv_regular',
      data: {
        otst: 'OTST-GPS',
        cod_metrica: 'MET-SIN-GPS',
        estado_servicio: 'Completo',
      },
    }],
    loadSupportSchemas(),
  );

  assert.equal(result.records[0].valid, true);
  assert.equal(result.records[0].location.latitud, -16.5);
  assert.equal(result.records[0].normalized.latitud, undefined);
  assert.equal(result.records[1].valid, true);
  assert.equal(result.records[1].location, null);
});
