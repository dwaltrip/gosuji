// modified slightly from: http://www.jacklmoore.com/notes/jquery-modal-tutorial/

var Modal = function(opts) {
    var that = this;
    var options = opts || {};
    var $overlay,
        $modal,
        $content,
        $close,
        hasCloseButton = defaultFor(options.closeButton, true);

    this.currentlyDisplayed = false;
    this.selector = '#modal';

    var init = function() {
        // Generate the HTML and add it to the document
        $overlay = $('<div id="modal-overlay"></div>');
        $modal = $('<div id="modal"></div>');
        $content = $('<div id="modal-content"></div>');
        $close = $('<a id="modal-close" href="#">close</a>');

        $modal.hide();
        $overlay.hide();
        $modal.append($content);
        if (hasCloseButton) $modal.append($close);

        $(document).ready(function(){
            $('body').append($overlay, $modal);
        });

        $close.click(function(e){
            e.preventDefault();
            that.close();
        });
    };

    // Open the modal
    this.open = function (settings) {
        $content.empty().append(settings.content);

        $modal.css({
            width: settings.width || 'auto',
            height: settings.height || 'auto'
        });

        center();
        $(window).bind('resize.modal', center);
        $modal.show();
        $overlay.show();
        that.currentlyDisplayed = true;
    };

    // Close the modal
    this.close = function () {
        $modal.hide();
        $overlay.hide();
        $content.empty();
        $(window).unbind('resize.modal');
        that.currentlyDisplayed = false;
    };

    // Center the modal in the viewport
    var center = function () {
        var top, left;

        top = Math.max($(window).height() - $modal.outerHeight(), 0) / 2;
        left = Math.max($(window).width() - $modal.outerWidth(), 0) / 2;

        $modal.css({
            top:top + $(window).scrollTop(),
            left:left + $(window).scrollLeft()
        });
    };

    init();
};

function defaultFor(arg, val) {
    return typeof arg !== 'undefined' ? arg: val;
}
