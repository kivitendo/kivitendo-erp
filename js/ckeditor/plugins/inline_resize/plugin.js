( function() {
  var win      = CKEDITOR.document.getWindow(),
      pixelate = CKEDITOR.tools.cssLength;

  CKEDITOR.plugins.add('inline_resize', {
    init: function( editor ) {
      var config = editor.config;

      editor.on('loaded', function() {
        attach(editor);
      }, null, null, 20); // same priority as floatspace so that both get initialized
    }
  });

  function attach( editor ) {
    var config = editor.config;

    var resize = function (width, height) {
      var editable;
      if ( !( editable = editor.editable() ) )
        return;

      editable.setStyle('width',  pixelate(width));
      editable.setStyle('height', pixelate(height));
    }

    var layout = function ( evt ) {
      var editable;
      if ( !( editable = editor.editable() ) )
          return;

      // Show up the space on focus gain.
      if (  evt && evt.name == 'focus' )
        float_space.show();

      var editorPos  = editable.getDocumentPosition();
      var editorRect = editable.getClientRect();
      var floatRect  = float_space.getClientRect();
      var viewRect   = win.getViewPaneSize();

      float_space.setStyle( 'position', 'absolute' );
      float_space.setStyle( 'top',    pixelate( editorPos.y + editorRect.height - floatRect.height + 1) );
      float_space.setStyle( 'right',  pixelate( viewRect.width - editorRect.right ) );
    };

    var float_html  = '<div class="cke_editor_inline_resize_button">\u25E2</div>'; // class so that csss can overrise content and style
    var float_space = CKEDITOR.document.getBody().append( CKEDITOR.dom.element.createFromHtml( float_html ));

    var drag_handler = function( evt ) {
      var width  = startSize.width  + evt.data.$.screenX - origin.x,
          height = startSize.height + evt.data.$.screenY - origin.y;

      width  = Math.max( config.resize_minWidth  || 200, Math.min( width  || 0, config.resize_maxWidth  || 9000) );
      height = Math.max( config.resize_minHeight || 75,  Math.min( height || 0, config.resize_maxHeight || 9000) );

      resize( width, height );
      layout();
    };

    var drag_end_handler = function() {
      CKEDITOR.document.removeListener( 'mousemove', drag_handler );
      CKEDITOR.document.removeListener( 'mouseup',   drag_end_handler );

      if ( editor.document ) {
        editor.document.removeListener( 'mousemove', drag_handler );
        editor.document.removeListener( 'mouseup',   drag_end_handler );
      }
    }

    var mousedown_fn =  function( evt ) {
      var editable;
      if ( !( editable = editor.editable() ) )
        return;

      var editorRect = editable.getClientRect();
      startSize      = { width: editorRect.width, height: editorRect.height };
      origin         = { x: evt.data.$.screenX, y: evt.data.$.screenY };

      if (config.resize_minWidth  > startSize.width)   config.resize_minWidth = startSize.width;
      if (config.resize_minHeight > startSize.height) config.resize_minHeight = startSize.height;

      CKEDITOR.document.on( 'mousemove', drag_handler );
      CKEDITOR.document.on( 'mouseup',   drag_end_handler );

      if ( editor.document ) {
        editor.document.on( 'mousemove', drag_handler );
        editor.document.on( 'mouseup',   drag_end_handler );
      }

      evt.data.$.preventDefault();
    };

    float_space.setStyle( 'overflow', 'hidden' );
    float_space.setStyle( 'cursor', 'se-resize' )
    float_space.on('mousedown', mousedown_fn);
    float_space.unselectable();
    float_space.hide();

    editor.on( 'focus', function( evt ) {
      layout( evt );
    } );

    editor.on( 'blur', function() {
      float_space.hide();
    } );

    editor.on( 'destroy', function() {
      float_space.remove();
    } );

    if ( editor.focusManager.hasFocus )
      float_space.show();

    editor.focusManager.add( float_space, 1 );
  }

})();

/*
  TODO
   * ltr support
   * textarea/div mode safe, currently simply assumes that textarea inline is used
   * positioning of resize handle is not browser zomm safe
*/
