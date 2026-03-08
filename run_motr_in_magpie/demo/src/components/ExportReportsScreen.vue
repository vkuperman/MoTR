<template>
  <Screen title="Saving reports">
    <Slide>
      <p>Saving fixation and interest area reports…</p>
      <Wait :time="0" @done="exportAndNext" />
    </Slide>
  </Screen>
</template>

<script>
import { Screen, Slide, Wait } from 'magpie-base';
import stringify from 'csv-stringify/lib/sync';
import JSZip from 'jszip';
import magpieConfig from '../magpie.config.js';

function isFixationRow(row) {
  return row != null && (row.mousePositionX != null && row.mousePositionX !== '');
}

function buildFixationReport(allRows) {
  const fixationRows = allRows.filter(isFixationRow);
  if (fixationRows.length === 0) return '';
  return stringify(fixationRows, {
    columns: Object.keys(fixationRows[0]),
    header: true
  });
}

function buildInterestAreaReport(allRows) {
  const fixationRows = allRows.filter(isFixationRow);
  if (fixationRows.length === 0) return '';

  const byItem = {};
  for (const row of fixationRows) {
    const id = row.ItemId;
    if (id == null || id === '') continue;
    if (!byItem[id]) byItem[id] = [];
    byItem[id].push(row);
  }

  const reportRows = [];
  for (const itemId of Object.keys(byItem)) {
    const rows = byItem[itemId];
    const fromTotal = Math.max(0, ...rows.map(r => r.totalWordsInItem).filter(w => w != null && w > 0));
    const fromMaxIndex = Math.max(0, ...rows.map(r => (r.Index != null && r.Index >= 1 ? Number(r.Index) : 0)));
    const totalWords = fromTotal > 0 ? fromTotal : fromMaxIndex;

    rows.sort((a, b) => (a.responseTime || 0) - (b.responseTime || 0));

    const wordIndices = new Set();
    for (let i = 1; i <= totalWords; i++) wordIndices.add(i);
    for (const r of rows) if (r.Index != null && r.Index >= 1) wordIndices.add(Number(r.Index));

    for (const wordIndex of [...wordIndices].sort((a, b) => a - b)) {
      const clicks = rows.filter(r => r.Index != null && Number(r.Index) === wordIndex);
      const clickCount = clicks.length;
      const skipped = clickCount === 0;

      const firstClick = clicks[0];
      const lastClick = clicks[clicks.length - 1];

      let firstClickX = '';
      let firstClickDurationMs = '';
      let totalDurationMs = '';
      let nextClickRegression = '';
      let xDistanceFromPreviousClick = '';
      let firstClickXFromWordLeftChars = '';
      let firstClickXFromWordCenterChars = '';
      let wordText = '';
      let positionInText = wordIndex;
      let lineNumber = '';
      let positionInLine = '';

      if (firstClick) {
        if (firstClick.line_number != null && firstClick.line_number !== '') lineNumber = firstClick.line_number;
        if (firstClick.position_in_line != null && firstClick.position_in_line !== '') positionInLine = firstClick.position_in_line;
        firstClickX = firstClick.mousePositionX;
        firstClickDurationMs = firstClick.clickDurationMs != null ? firstClick.clickDurationMs : '';
        totalDurationMs = clicks.reduce((sum, c) => sum + (c.clickDurationMs != null ? c.clickDurationMs : 0), 0);
        wordText = firstClick.Word != null ? firstClick.Word : '';

        const wordLeft = firstClick.wordPositionLeft;
        const wordRight = firstClick.wordPositionRight;
        const wordLen = (firstClick.Word && firstClick.Word.length) || 1;
        const charWidth = (wordRight != null && wordLeft != null && wordRight > wordLeft)
          ? (wordRight - wordLeft) / wordLen
          : null;
        if (charWidth && charWidth > 0) {
          firstClickXFromWordLeftChars = ((firstClick.mousePositionX - wordLeft) / charWidth).toFixed(4);
          const centerX = (wordLeft + wordRight) / 2;
          firstClickXFromWordCenterChars = ((firstClick.mousePositionX - centerX) / charWidth).toFixed(4);
        }

        const prevClicks = rows.filter(r => (r.responseTime || 0) < (firstClick.responseTime || 0) && r.Index != null && Number(r.Index) !== wordIndex);
        const prevClick = prevClicks.length ? prevClicks[prevClicks.length - 1] : null;
        if (prevClick != null && prevClick.mousePositionX != null) {
          xDistanceFromPreviousClick = (firstClick.mousePositionX - prevClick.mousePositionX).toFixed(2);
        }

        const nextClicks = rows.filter(r => (r.responseTime || 0) > (lastClick.responseTime || 0) && r.Index != null && Number(r.Index) !== wordIndex);
        const nextClick = nextClicks.length ? nextClicks[0] : null;
        if (nextClick != null && nextClick.Index != null) {
          nextClickRegression = Number(nextClick.Index) < wordIndex ? '1' : '0';
        }
      }

      const experiment = (rows[0] && rows[0].Experiment) != null ? rows[0].Experiment : '';
      const condition = (rows[0] && rows[0].Condition) != null ? rows[0].Condition : '';

      reportRows.push({
        Experiment: experiment,
        Condition: condition,
        ItemId: itemId,
        position_in_text: positionInText,
        line_number: lineNumber,
        position_in_line: positionInLine,
        word_index: wordIndex,
        word: wordText,
        click_count: clickCount,
        skipped: skipped ? '1' : '0',
        first_click_x: firstClickX,
        first_click_duration_ms: firstClickDurationMs,
        total_duration_ms: totalDurationMs,
        next_click_regression: nextClickRegression,
        x_distance_from_previous_click: xDistanceFromPreviousClick,
        first_click_x_from_word_left_chars: firstClickXFromWordLeftChars,
        first_click_x_from_word_center_chars: firstClickXFromWordCenterChars
      });
    }
  }

  if (reportRows.length === 0) return '';
  return stringify(reportRows, {
    columns: Object.keys(reportRows[0]),
    header: true
  });
}

function getResultsFolderName(participantId) {
  const d = new Date();
  const pad = n => String(n).padStart(2, '0');
  const datePart = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}_${pad(d.getHours())}-${pad(d.getMinutes())}`;
  const id = participantId && String(participantId) ? String(participantId) : 'unknown';
  return `motr_results_${id}_${datePart}`;
}

function buildResultsZipBlob(fixationCsv, interestAreaCsv, folderName) {
  const zip = new JSZip();
  if (fixationCsv) zip.file(`${folderName}/fixation_report.csv`, fixationCsv);
  if (interestAreaCsv) zip.file(`${folderName}/interest_area_report.csv`, interestAreaCsv);
  return zip.generateAsync({ type: 'blob' });
}

function blobToBase64(blob) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onloadend = () => {
      const dataUrl = reader.result;
      const base64 = dataUrl.indexOf(',') >= 0 ? dataUrl.split(',')[1] : dataUrl;
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(blob);
  });
}

export default {
  name: 'ExportReportsScreen',
  components: { Screen, Slide, Wait },
  methods: {
    async exportAndNext() {
      const allRows = this.$magpie.getAllData();
      const fixationCsv = buildFixationReport(allRows);
      const interestAreaCsv = buildInterestAreaReport(allRows);

      const participantId = (this.$root && this.$root.participantId) || null;
      const folderName = getResultsFolderName(participantId);

      if (fixationCsv || interestAreaCsv) {
        const blob = await buildResultsZipBlob(fixationCsv, interestAreaCsv, folderName);
        const uploadUrl = magpieConfig.resultsUploadUrl;
        if (uploadUrl && typeof uploadUrl === 'string' && uploadUrl.trim() !== '') {
          try {
            const zipBase64 = await blobToBase64(blob);
            const res = await fetch(uploadUrl.trim(), {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ participantId: participantId || 'unknown', zipBase64 })
            });
            if (!res.ok) {
              const errText = await res.text();
              throw new Error(`${res.status} ${errText}`);
            }
          } catch (e) {
            console.error('Results upload failed:', e.message || e);
          }
        }
      }

      this.$magpie.nextSlide();
    }
  }
};
</script>
