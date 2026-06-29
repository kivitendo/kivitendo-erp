// Allow CKeditor to work in jQuery dialogs. See
// http://bugs.jqueryui.com/ticket/9087

$.widget( "ui.dialog", $.ui.dialog, {
 /*! jQuery UI - v1.10.2 - 2013-12-12
  *  http://bugs.jqueryui.com/ticket/9087#comment:27 - bugfix
  *  http://bugs.jqueryui.com/ticket/4727#comment:23 - bugfix
  *  allowInteraction fix to accommodate windowed editors
  */
  _allowInteraction: function( event ) {
    if ( this._super( event ) ) {
      return true;
    }

    // address interaction issues with general iframes with the dialog
    if ( event.target.ownerDocument != this.document[ 0 ] ) {
      return true;
    }

    // address interaction issues with dialog window
    if ( $( event.target ).closest( ".cke_dialog" ).length ) {
      return true;
    }

    // address interaction issues with iframe based drop downs in IE
    if ( $( event.target ).closest( ".cke" ).length ) {
      return true;
    }
  },
 /*! jQuery UI - v1.10.2 - 2013-10-28
  *  http://dev.ckeditor.com/ticket/10269 - bugfix
  *  moveToTop fix to accommodate windowed editors
  */
  _moveToTop: function ( event, silent ) {
    if ( !event || !this.options.modal ) {
      this._super( event, silent );
    }
  }

});
