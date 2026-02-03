// QuickFit PMTiles Protocol Initialization
// This script sets up the PMTiles protocol for MapLibre GL on web

(function() {
  'use strict';
  
  // Wait for PMTiles library to load
  if (typeof pmtiles === 'undefined') {
    console.warn('PMTiles library not loaded yet');
    return;
  }
  
  // Create and register the PMTiles protocol
  const protocol = new pmtiles.Protocol();
  
  // Register with MapLibre (happens automatically when maplibregl is available)
  if (typeof maplibregl !== 'undefined') {
    maplibregl.addProtocol('pmtiles', protocol.tile);
    console.log('✅ PMTiles protocol registered for MapLibre GL');
  }
  
  // Export for use in Flutter/Dart via JS interop
  window.QuickFitMap = {
    protocol: protocol,
    
    // Get the Israel PMTiles style JSON with dark theme
    getDarkStyle: function(tilesPath) {
      const pmtilesUrl = 'pmtiles://' + tilesPath;
      
      return {
        version: 8,
        glyphs: 'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf',
        sprite: 'https://protomaps.github.io/basemaps-assets/sprites/v4/dark',
        sources: {
          'protomaps': {
            type: 'vector',
            url: pmtilesUrl,
            attribution: '© <a href="https://openstreetmap.org">OpenStreetMap</a>'
          }
        },
        layers: basemaps.layers('protomaps', basemaps.namedFlavor('dark'), { lang: 'en' })
      };
    },
    
    // Get the Israel PMTiles style JSON with light theme
    getLightStyle: function(tilesPath) {
      const pmtilesUrl = 'pmtiles://' + tilesPath;
      
      return {
        version: 8,
        glyphs: 'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf',
        sprite: 'https://protomaps.github.io/basemaps-assets/sprites/v4/light',
        sources: {
          'protomaps': {
            type: 'vector',
            url: pmtilesUrl,
            attribution: '© <a href="https://openstreetmap.org">OpenStreetMap</a>'
          }
        },
        layers: basemaps.layers('protomaps', basemaps.namedFlavor('light'), { lang: 'en' })
      };
    },
    
    // Get style as JSON string (for Flutter interop)
    getDarkStyleJson: function(tilesPath) {
      return JSON.stringify(this.getDarkStyle(tilesPath));
    },
    
    getLightStyleJson: function(tilesPath) {
      return JSON.stringify(this.getLightStyle(tilesPath));
    }
  };
  
  console.log('✅ QuickFitMap initialized with Israel PMTiles support');
})();
