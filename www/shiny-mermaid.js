
Shiny.addCustomMessageHandler("get_element_by_id", function(msg){
 Shiny.setInputValue(msg, [getBase64SVG(), Math.random()]);
})

const getSvgEl = () => {
    const svgEl = document
      .querySelector('#mermaid svg')

    const fontAwesomeCdnUrl = Array.from(document.head.getElementsByTagName('link'))
      .map((l) => l.href)
      .find((h) => h.includes('font-awesome'));
    if (fontAwesomeCdnUrl == null) {
      return svgEl;
    }
    const styleEl = document.createElement('style');
    styleEl.innerText = `@import url("${fontAwesomeCdnUrl}");'`;
    svgEl.prepend(styleEl);
    return svgEl;
  };

const getBase64SVG = (svg) => {
    if (!svg) {
      svg = getSvgEl();
    }
    const svgString = svg.outerHTML
      .replaceAll('<br>', '<br/>')
      .replaceAll(/<img([^>]*)>/g, (m, g) => `<img ${g} />`);
    return svgString;
  };
