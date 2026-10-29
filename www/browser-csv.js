// Bind CSV data URLs produced in webR. Ordinary R hosting keeps downloadHandler.
const csvOutput = new Shiny.OutputBinding();
csvOutput.find = function(scope) { return $(scope).find('a.browser-csv-link'); };
csvOutput.renderValue = function(element, value) {
  const csv = JSON.parse(value);
  element.href = csv.href;
  element.download = csv.filename;
  element.classList.remove('disabled');
  element.removeAttribute('aria-disabled');
  element.removeAttribute('tabindex');
  element.removeAttribute('target');
};
csvOutput.renderError = function(element) {
  element.removeAttribute('href');
  element.classList.add('disabled');
};
Shiny.outputBindings.register(csvOutput, 'electionLab.csv');
