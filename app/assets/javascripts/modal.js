// modified slightly from: http://www.jacklmoore.com/notes/jquery-modal-tutorial/

var Modal = function(opts) {
    var options = opts || {};
    var method = {},
        $overlay,
        $modal,
        $content,
        $close,
        hasCloseButton = defaultFor(options.closeButton, true);

    method.currentlyDisplayed = false;
    method.contentId = '#modal-content';

    // Center the modal in the viewport
    method.center = function () {
        var top, left;

        top = Math.max($(window).height() - $modal.outerHeight(), 0) / 2;
        left = Math.max($(window).width() - $modal.outerWidth(), 0) / 2;

        $modal.css({
            top:top + $(window).scrollTop(),
            left:left + $(window).scrollLeft()
        });
    };

    // Open the modal
    method.open = function (settings) {
        console.log('-- hi friends');
        $content.empty().append(settings.content);

        $modal.css({
            width: settings.width || 'auto', 
            height: settings.height || 'auto'
        });

        method.center();
        $(window).bind('resize.modal', method.center);
        $modal.show();
        $overlay.show();
        method.currentlyDisplayed = true;

        console.log('-- bye friends');
    };

    // Close the modal
    method.close = function () {
        $modal.hide();
        $overlay.hide();
        $content.empty();
        $(window).unbind('resize.modal');
        method.currentlyDisplayed = false;
    };

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
        method.close();
    });

    return method;
};

function defaultFor(arg, val) {
    return typeof arg !== 'undefined' ? arg: val;
}
