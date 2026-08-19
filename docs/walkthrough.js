import { scenarios } from './walkthrough-data.js';

const tabs = [...document.querySelectorAll('[role="tab"]')];
const panel = document.querySelector('#scenario-panel');
const progress = document.querySelector('#scenario-progress');
const fields = {
  kicker: document.querySelector('#scenario-kicker'),
  title: document.querySelector('#scenario-title'),
  rule: document.querySelector('#scenario-rule'),
  expected: document.querySelector('#scenario-expected'),
  limitation: document.querySelector('#scenario-limitation'),
  evidence: document.querySelector('#scenario-evidence'),
  image: document.querySelector('#scenario-image'),
  imageLink: document.querySelector('#scenario-image-link'),
  caption: document.querySelector('#scenario-caption'),
  hash: document.querySelector('#scenario-hash')
};

function renderEvidence(items) {
  fields.evidence.replaceChildren(
    ...items.map(({ label, href }) => {
      const link = document.createElement('a');
      link.href = href;
      link.textContent = label;
      const item = document.createElement('li');
      item.append(link);
      return item;
    })
  );
}

function selectScenario(index, moveFocus = false) {
  const scenario = scenarios[index];
  const selectedTab = tabs[index];

  tabs.forEach((tab, tabIndex) => {
    const selected = tabIndex === index;
    tab.setAttribute('aria-selected', String(selected));
    tab.tabIndex = selected ? 0 : -1;
  });

  panel.setAttribute('aria-labelledby', selectedTab.id);
  fields.kicker.textContent = scenario.kicker;
  fields.title.textContent = scenario.title;
  fields.rule.textContent = scenario.rule;
  fields.expected.textContent = scenario.expected;
  fields.limitation.textContent = scenario.limitation;
  fields.image.src = `./${scenario.visual.src}`;
  fields.image.alt = scenario.visual.alt;
  fields.imageLink.href = `./${scenario.visual.src}`;
  fields.imageLink.setAttribute('aria-label', `Open full-size image: ${scenario.visual.caption}`);
  fields.caption.textContent = scenario.visual.caption;
  fields.hash.textContent = scenario.visual.sha256;
  progress.textContent = `Scenario ${index + 1} of ${scenarios.length}`;
  renderEvidence(scenario.evidence);

  if (moveFocus) {
    selectedTab.focus();
  }
}

tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectScenario(index));
  tab.addEventListener('keydown', (event) => {
    let nextIndex;
    if (event.key === 'ArrowRight') {
      nextIndex = (index + 1) % tabs.length;
    } else if (event.key === 'ArrowLeft') {
      nextIndex = (index - 1 + tabs.length) % tabs.length;
    } else if (event.key === 'Home') {
      nextIndex = 0;
    } else if (event.key === 'End') {
      nextIndex = tabs.length - 1;
    } else {
      return;
    }

    event.preventDefault();
    selectScenario(nextIndex, true);
  });
});

selectScenario(0);
