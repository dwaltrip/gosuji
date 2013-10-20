
console.log('Successfully loaded games.js')

var ready = function() {
    console.log('Adding click handler to clickable tiles.');

    $('div.tile_container.clickable').click(function() {
        var tile_pos = $(this).data('board-pos');
        console.log('Submitting form for tile pos: ' + tile_pos);

        $('<input />').attr('type', 'hidden')
                      .attr('name', 'new_move')
                      .attr('value', tile_pos)
                      .appendTo('#board-form');
        $('#board-form').submit();
    });
};

$(document).ready(ready);
$(document).on('page:load', ready);

