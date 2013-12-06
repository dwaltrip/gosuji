console.log('Successfully loaded games.js')

var ready = function() {
    console.log('Adding click handler to clickable tiles.');

    $('div.tile_container.clickable').on('click.new_move', function() {
        var tile_pos = $(this).data('board-pos');
        console.log('Inside click.new_move handler for tile pos: ' + tile_pos);

        $('<input />').attr('type', 'hidden')
                      .attr('name', 'new_move')
                      .attr('value', tile_pos)
                      .appendTo('#board-form');

        console.log('submitting form via jquery/ajax');
        $.post($('#board-form').attr('action'), $('#board-form').serialize(), on_success, 'script');
    });

    function on_success(data, textStatus, jqXHR) {
        console.log('-- ajax post succeeded! -- textStatus: ' + textStatus + ', jqXHR: ' + jqXHR);
    }
};

$(document).ready(ready);
$(document).on('page:load', ready);
