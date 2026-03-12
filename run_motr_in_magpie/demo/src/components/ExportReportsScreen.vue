<template>
  <Screen title="Thank you">
    <Slide v-if="!skipSonaInput && !submitted">
      <p>
        Thank you for participating in this study. Press Submit to complete.
      </p>
      <div style="margin-top: 1.5em;">
        <button @click="submitSonaAndNext">
          Submit
        </button>
      </div>
    </Slide>
    <Slide v-else>
      <!-- Blank thank-you page (when skipSonaInput, export runs automatically) -->
      <div></div>
    </Slide>
  </Screen>
</template>

<script>
import { Screen, Slide } from 'magpie-base';
import stringify from 'csv-stringify/lib/sync';
import JSZip from 'jszip';
import magpieConfig from '../magpie.config.js';
import provo_list1 from '../../provo/trials/provo_items_list1.tsv';
import provo_list2 from '../../provo/trials/provo_items_list2.tsv';
import provo_list3 from '../../provo/trials/provo_items_list3.tsv';
import provo_practice from '../../provo/trials/provo_items_practice.tsv';

function generateUniqueAlphanumericId() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s = '';
  for (let i = 0; i < 8; i++) s += chars[Math.floor(Math.random() * chars.length)];
  return s;
}

// ItemId: identifier of the text/trial item (e.g. sentence or passage) being read; one item per screen before the comprehension question.
function isFixationRow(row) {
  return row != null && (row.mousePositionX != null && row.mousePositionX !== '');
}

function getResponseByItem(allRows) {
  const out = {};
  if (!Array.isArray(allRows)) return out;
  for (const r of allRows) {
    if (!r) continue;
    const itemId = r.ItemId != null && r.ItemId !== '' ? r.ItemId : (r.item_id != null && r.item_id !== '' ? r.item_id : null);
    const resp = r.response != null ? String(r.response) : (r.responses && Array.isArray(r.responses) ? r.responses.join('|') : (r.responses && typeof r.responses === 'object' ? JSON.stringify(r.responses) : ''));
    if (itemId != null && (resp !== '' || r.response !== undefined)) {
      if (resp !== '' || out[itemId] == null) out[itemId] = resp;
    }
  }
  return out;
}

function getExpDataFields(expData, allRows, sessionTimes) {
  const fromRows = { device: '', hand: '' };
  let subjectFromRows = '';
  if (Array.isArray(allRows)) {
    for (let i = allRows.length - 1; i >= 0; i--) {
      const r = allRows[i];
      if (r && (r.device != null && r.device !== '' || r.hand != null && r.hand !== '')) {
        if (r.device != null && r.device !== '') fromRows.device = r.device;
        if (r.hand != null && r.hand !== '') fromRows.hand = r.hand;
        break;
      }
    }
  }
  if (Array.isArray(allRows)) {
    for (const r of allRows) {
      if (!r) continue;
      if (r.SONAId != null && r.SONAId !== '') {
        subjectFromRows = r.SONAId;
        break;
      }
      if (r.SubjectId != null && r.SubjectId !== '') {
        subjectFromRows = r.SubjectId;
        break;
      }
      if (r.SubjectID != null && r.SubjectID !== '') {
        subjectFromRows = r.SubjectID;
        break;
      }
      if (r.SonaId != null && r.SonaId !== '') {
        subjectFromRows = r.SonaId;
        break;
      }
    }
  }
  const exp = expData && typeof expData === 'object' ? expData : {};
  const startTime = exp.experiment_start_time != null ? exp.experiment_start_time : (exp.experimentStartTime != null ? exp.experimentStartTime : (sessionTimes && sessionTimes.experiment_start_time_fallback != null ? sessionTimes.experiment_start_time_fallback : ''));
  const endTime = sessionTimes && sessionTimes.experiment_end_time != null ? sessionTimes.experiment_end_time : '';
  const duration = sessionTimes && sessionTimes.experiment_duration != null ? sessionTimes.experiment_duration : '';
  const sonaIdValue =
    (exp.SONAId != null && exp.SONAId !== '')
      ? exp.SONAId
      : (exp.SubjectId != null && exp.SubjectId !== ''
        ? exp.SubjectId
        : (exp.SubjectID != null && exp.SubjectID !== ''
          ? exp.SubjectID
          : subjectFromRows));

  return {
    device: exp.device != null && exp.device !== '' ? exp.device : fromRows.device,
    hand: exp.hand != null && exp.hand !== '' ? exp.hand : fromRows.hand,
    SONAId: sonaIdValue,
    experiment: exp.experiment != null ? exp.experiment : (exp.Experiment != null ? exp.Experiment : ''),
    experiment_start_time: startTime,
    experiment_end_time: endTime,
    experiment_duration: duration
  };
}

const FIXATION_CSV_COLUMNS = [
  'participant_id', 'SONAId', 'Condition', 'ItemId', 'text_presentation_order', 'WordIndex', 'Word',
  'responseTime', 'mousePositionX', 'mousePositionY', 'clickDurationMs',
  'relativeXInWord', 'relativeYInWord',
  'wordPositionTop', 'wordPositionLeft', 'wordPositionBottom', 'wordPositionRight',
  'line_number', 'position_in_line', 'response', 'position_in_text',
  'device', 'hand', 'experiment_start_time', 'experiment_end_time', 'experiment_duration',
  'experiment'
];

// Build a lookup from Provo ItemId to its full text, so we can
// fill the word column for skipped words in the interest-area report.
const allProvoItems = [...provo_practice, ...provo_list1, ...provo_list2, ...provo_list3];
const provoTextByItemId = {};
for (const trial of allProvoItems) {
  const id = trial.item_id != null ? trial.item_id : (trial.ItemId != null ? trial.ItemId : null);
  const text = trial.text != null ? trial.text : '';
  if (id != null && text !== '') {
    provoTextByItemId[String(id)] = String(text);
  }
}

const INTEREST_AREA_CSV_COLUMNS = [
  'participant_id', 'SONAId', 'Condition', 'ItemId', 'text_presentation_order',
  'word_index', 'word', 'response', 'position_in_text', 'line_number', 'position_in_line',
  'click_count', 'skipped',
  'first_click_x', 'first_click_duration_ms', 'total_duration_ms', 'next_click_regression',
  'x_distance_from_previous_click_px', 'x_distance_from_previous_click_chars',
  'first_click_x_from_word_left_chars', 'first_click_x_from_word_center_chars',
  'first_click_x_from_line_start_px', 'first_click_x_from_line_start_chars',
  'device', 'hand', 'experiment_start_time', 'experiment_end_time', 'experiment_duration'
];

function buildFixationReport(allRows, participantId, expData, sessionTimes) {
  const fixationRows = allRows.filter(isFixationRow);
  if (fixationRows.length === 0) return '';
  const pid = participantId != null && String(participantId) ? String(participantId) : '';
  const expFields = getExpDataFields(expData, allRows, sessionTimes);
  const responseByItem = getResponseByItem(allRows);

  const rowsWithMeta = fixationRows.map(r => {
    const itemId = r.ItemId != null && r.ItemId !== '' ? r.ItemId : 'NO_ITEM';
    const positionInText = r.Index != null && r.Index !== '' ? r.Index : '';
    return {
      ...r,
      participant_id: pid,
      position_in_text: positionInText,
      response: responseByItem[itemId] != null ? responseByItem[itemId] : '',
      ...expFields
    };
  });

  const rowsForCsv = rowsWithMeta.map(row => {
    const out = {};
    const val = (key) => (row[key] != null && row[key] !== '' ? row[key] : '');
    out.participant_id = pid;
    out.SONAId = val('SONAId');
    out.Condition = val('Condition');
    out.ItemId = val('ItemId');
    out.text_presentation_order = row.presentation_order != null && row.presentation_order !== '' ? Number(row.presentation_order) : '';
    out.WordIndex = row.Index != null && row.Index !== '' ? row.Index : '';
    out.Word = val('Word');
    out.responseTime = val('responseTime');
    out.mousePositionX = val('mousePositionX');
    out.mousePositionY = val('mousePositionY');
    out.clickDurationMs = val('clickDurationMs');
    out.relativeXInWord = val('relativeXInWord');
    out.relativeYInWord = val('relativeYInWord');
    out.wordPositionTop = val('wordPositionTop');
    out.wordPositionLeft = val('wordPositionLeft');
    out.wordPositionBottom = val('wordPositionBottom');
    out.wordPositionRight = val('wordPositionRight');
    out.line_number = val('line_number');
    out.position_in_line = val('position_in_line');
    out.response = val('response');
    out.position_in_text = val('position_in_text');
    out.device = val('device');
    out.hand = val('hand');
    out.experiment_start_time = val('experiment_start_time');
    out.experiment_end_time = val('experiment_end_time');
    out.experiment_duration = val('experiment_duration');
    out.experiment = val('experiment');
    return out;
  });

  rowsForCsv.sort((a, b) => {
    const poA = a.text_presentation_order === '' ? Infinity : Number(a.text_presentation_order);
    const poB = b.text_presentation_order === '' ? Infinity : Number(b.text_presentation_order);
    if (poA !== poB) return poA - poB;
    const rtA = a.responseTime === '' ? Infinity : Number(a.responseTime);
    const rtB = b.responseTime === '' ? Infinity : Number(b.responseTime);
    return rtA - rtB;
  });

  return stringify(rowsForCsv, {
    columns: FIXATION_CSV_COLUMNS,
    header: true
  });
}

function buildInterestAreaReport(allRows, participantId, expData, sessionTimes) {
  const fixationRows = allRows.filter(isFixationRow);
  if (fixationRows.length === 0) return '';
  const pid = participantId != null && String(participantId) ? String(participantId) : '';
  const expFields = getExpDataFields(expData, allRows, sessionTimes);
  const responseByItem = getResponseByItem(allRows);

  const byItem = {};
  for (const row of fixationRows) {
    const id = row.ItemId != null && row.ItemId !== '' ? row.ItemId : 'NO_ITEM';
    if (!byItem[id]) byItem[id] = [];
    byItem[id].push(row);
  }

  const reportRows = [];
  const firstTimeByItem = {};
  for (const itemId of Object.keys(byItem)) {
    const rowsForItem = byItem[itemId];
    firstTimeByItem[itemId] = Math.min(...rowsForItem.map(r => r.responseTime || 0));
  }
  const presentationOrderByItem = {};
  for (const itemId of Object.keys(byItem)) {
    const rowsForItem = byItem[itemId];
    const firstWithOrder = rowsForItem.find(r => r.presentation_order != null && r.presentation_order !== '');
    if (firstWithOrder) {
      const val = Number(firstWithOrder.presentation_order);
      if (!Number.isNaN(val)) presentationOrderByItem[itemId] = val;
    }
  }

  // Sort items primarily by text presentation order, fallback to first-click time.
  const sortedItemIds = Object.keys(byItem).sort((a, b) => {
    const pa = presentationOrderByItem[a];
    const pb = presentationOrderByItem[b];
    if (pa != null && pb != null && pa !== pb) return pa - pb;
    if (pa != null && pb == null) return -1;
    if (pa == null && pb != null) return 1;
    const ta = firstTimeByItem[a] || 0;
    const tb = firstTimeByItem[b] || 0;
    return ta - tb;
  });

  let itemOrderCounter = 0;
  for (const itemId of sortedItemIds) {
    itemOrderCounter += 1;
    const rows = byItem[itemId];
    const fromTotal = Math.max(0, ...rows.map(r => r.totalWordsInItem).filter(w => w != null && w > 0));
    const fromMaxIndex = Math.max(0, ...rows.map(r => (r.Index != null && r.Index >= 1 ? Number(r.Index) : 0)));
    const totalWords = fromTotal > 0 ? fromTotal : fromMaxIndex;

    rows.sort((a, b) => (a.responseTime || 0) - (b.responseTime || 0));

    // Get the full word list for this item from the Provo trial texts.
    const textForItem = provoTextByItemId[String(itemId)] || '';
    const wordsFromTrials = textForItem ? String(textForItem).split(' ') : null;

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
      let xDistanceFromPreviousClickChars = '';
      let firstClickXFromWordLeftChars = '';
      let firstClickXFromWordCenterChars = '';
      let firstClickXFromLineStartPx = '';
      let firstClickXFromLineStartChars = '';
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

        if (firstClick.xFromLineStartPx != null) {
          firstClickXFromLineStartPx = Number(firstClick.xFromLineStartPx).toFixed(2);
        }
        if (firstClick.xFromLineStartChars != null) {
          firstClickXFromLineStartChars = Number(firstClick.xFromLineStartChars).toFixed(4);
        }

        const prevClicks = rows.filter(r => (r.responseTime || 0) < (firstClick.responseTime || 0) && r.Index != null && Number(r.Index) !== wordIndex);
        const prevClick = prevClicks.length ? prevClicks[prevClicks.length - 1] : null;
        if (prevClick != null && prevClick.mousePositionX != null) {
          xDistanceFromPreviousClick = (firstClick.mousePositionX - prevClick.mousePositionX).toFixed(2);
          if (charWidth && charWidth > 0) {
            xDistanceFromPreviousClickChars = (Number(xDistanceFromPreviousClick) / charWidth).toFixed(4);
          }
        }

        const nextClicks = rows.filter(r => (r.responseTime || 0) > (lastClick.responseTime || 0) && r.Index != null && Number(r.Index) !== wordIndex);
        const nextClick = nextClicks.length ? nextClicks[0] : null;
        if (nextClick != null && nextClick.Index != null) {
          nextClickRegression = Number(nextClick.Index) < wordIndex ? '1' : '0';
        }
      }

      // If no click-based word text, fall back to the recorded word list for skipped words.
      if ((!wordText || wordText === '') && wordsFromTrials && wordsFromTrials[wordIndex - 1] != null) {
        wordText = wordsFromTrials[wordIndex - 1];
      }

      const experiment = (rows[0] && rows[0].Experiment) != null ? rows[0].Experiment : '';
      const condition = (rows[0] && rows[0].Condition) != null ? rows[0].Condition : '';

      const response = responseByItem[itemId] != null ? responseByItem[itemId] : '';
      reportRows.push({
        participant_id: pid,
        response,
        device: expFields.device,
        hand: expFields.hand,
        experiment_start_time: expFields.experiment_start_time,
        SONAId: expFields.SONAId,
        experiment_end_time: expFields.experiment_end_time,
        experiment_duration: expFields.experiment_duration,
        experiment: expFields.experiment,
        Experiment: experiment,
        Condition: condition,
        ItemId: itemId,
        text_presentation_order: presentationOrderByItem[itemId] != null ? presentationOrderByItem[itemId] : itemOrderCounter,
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
        x_distance_from_previous_click_px: xDistanceFromPreviousClick,
        x_distance_from_previous_click_chars: xDistanceFromPreviousClickChars,
        first_click_x_from_word_left_chars: firstClickXFromWordLeftChars,
        first_click_x_from_word_center_chars: firstClickXFromWordCenterChars,
        first_click_x_from_line_start_px: firstClickXFromLineStartPx,
        first_click_x_from_line_start_chars: firstClickXFromLineStartChars
      });
    }
  }

  if (reportRows.length === 0) return '';

  const rowsForCsv = reportRows.map(row => {
    const val = (key) => (row[key] != null && row[key] !== '' ? row[key] : '');
    return {
      participant_id: val('participant_id'),
      SONAId: val('SONAId'),
      Condition: val('Condition'),
      ItemId: val('ItemId'),
      text_presentation_order: val('text_presentation_order'),
      word_index: val('word_index'),
      word: val('word'),
      response: val('response'),
      position_in_text: val('position_in_text'),
      line_number: val('line_number'),
      position_in_line: val('position_in_line'),
      click_count: val('click_count'),
      skipped: val('skipped'),
      first_click_x: val('first_click_x'),
      first_click_duration_ms: val('first_click_duration_ms'),
      total_duration_ms: val('total_duration_ms'),
      next_click_regression: val('next_click_regression'),
      x_distance_from_previous_click_px: val('x_distance_from_previous_click_px'),
      x_distance_from_previous_click_chars: val('x_distance_from_previous_click_chars'),
      first_click_x_from_word_left_chars: val('first_click_x_from_word_left_chars'),
      first_click_x_from_word_center_chars: val('first_click_x_from_word_center_chars'),
      first_click_x_from_line_start_px: val('first_click_x_from_line_start_px'),
      first_click_x_from_line_start_chars: val('first_click_x_from_line_start_chars'),
      device: val('device'),
      hand: val('hand'),
      experiment_start_time: val('experiment_start_time'),
      experiment_end_time: val('experiment_end_time'),
      experiment_duration: val('experiment_duration')
    };
  });

  rowsForCsv.sort((a, b) => {
    const poA = a.text_presentation_order === '' ? Infinity : Number(a.text_presentation_order);
    const poB = b.text_presentation_order === '' ? Infinity : Number(b.text_presentation_order);
    if (poA !== poB) return poA - poB;
    const wiA = a.word_index === '' ? -1 : Number(a.word_index);
    const wiB = b.word_index === '' ? -1 : Number(b.word_index);
    return wiA - wiB;
  });

  return stringify(rowsForCsv, {
    columns: INTEREST_AREA_CSV_COLUMNS,
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
  components: { Screen, Slide },
  props: {
    skipSonaInput: { type: Boolean, default: false }
  },
  data() {
    return {
      sonaId: '',
      submitted: false
    };
  },
  mounted() {
    if (this.skipSonaInput) {
      this.submitDirectAndNext();
    }
  },
  methods: {
    async exportAndNext() {
      const allRows = this.$magpie.getAllData();
      const expData = (this.$magpie.getExpData && this.$magpie.getExpData()) || {};
      let participantId = expData.ParticipantId || (this.$root && this.$root.participantId) || null;
      if (!participantId || String(participantId).trim() === '') {
        participantId = generateUniqueAlphanumericId();
        if (this.$magpie.addExpData) this.$magpie.addExpData({ ParticipantId: participantId });
      }
      participantId = String(participantId).trim();
      const endTime = new Date();
      let startTime = expData.experiment_start_time || expData.experimentStartTime;
      if (!startTime && Array.isArray(allRows) && allRows.length > 0) {
        const minT = Math.min(...allRows.map(r => (r.responseTime != null && typeof r.responseTime === 'number' ? r.responseTime : Infinity)).filter(t => t !== Infinity));
        if (minT !== Infinity && Number.isFinite(minT)) startTime = new Date(minT).toISOString();
      }
      const durationMs = startTime ? (endTime.getTime() - new Date(startTime).getTime()) : '';
      const sessionTimes = {
        experiment_end_time: endTime.toISOString(),
        experiment_duration: durationMs !== '' ? String(durationMs) : '',
        experiment_start_time_fallback: startTime || ''
      };
      const fixationCsv = buildFixationReport(allRows, participantId, expData, sessionTimes);
      const interestAreaCsv = buildInterestAreaReport(allRows, participantId, expData, sessionTimes);
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
              body: JSON.stringify({ participantId, zipBase64 })
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
    },
    async submitSonaAndNext() {
      this.submitted = true;
      await this.exportAndNext();
    },
    async submitDirectAndNext() {
      this.submitted = true;
      await this.exportAndNext();
    }
  }
};
</script>
