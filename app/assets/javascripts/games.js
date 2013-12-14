console.log('Successfully loaded games.js')

var socket = null;

var ready = function() {
    add_move_handler();

    console.log('--- game_id: ' + game_id);
    socket = get_socket();
    socket.emit('subscribe-to-updates', { room_id: 'game-' + game_id });
};

function add_move_handler() {
    console.log('Adding click handler to clickable tiles.');

    $('div.tile_container.clickable').on('click.new_move', function() {
        var tile_pos = $(this).data('board-pos');
        console.log('Inside click.new_move handler for tile pos: ' + tile_pos);

        var move_id = 'game-' + game_id + '-move-' + move_num;
        add_hidden_input('#board-form', 'new_move', tile_pos);
        add_hidden_input('#board-form', 'move_id', move_id);

        console.log('submitting form via jquery/ajax');

        $('div.tile_container.clickable').removeClass('clickable');
        $('div.tile_container').off('click.new_move');

        $.post($('#board-form').attr('action'), $('#board-form').serialize(), on_success, 'script');
        socket.emit('submitted-move', { move_id: move_id });
    });
}

function update_game(tiles, invalid_moves, header_html) {
    $('#header_container').html(header_html);

    for(var i = 0; i < tiles.length; i++) {
        var new_tile = $(tiles[i].html).find('div.tile_container');
        $('#tile-' + tiles[i].pos).html(new_tile[0].outerHTML);
    }

    $('div.tile_container.empty_tile').addClass('clickable');
    for(var i = 0; i < invalid_moves.length; i++) {
        var selector = '#tile-' + invalid_moves[i] + ' > div.tile_container';
        $(selector).removeClass('clickable');
    }

    move_num += 1;

    add_move_handler();
}

function get_socket() {
    console.log('-- sockjs_url: ' + sockjs_url + '\n');

    var sockjs = new SockjsClient(sockjs_url);

    sockjs.on('connect', function() {
        console.log("sockjs successfully connected with protocol '" + sockjs.protocol + "'");
        sockjs.emit('successfully-connnected', { info: 'hello server, client has connected' });
    });

    sockjs.on('message', function(data) {
        console.log("    inside sockjs.on('message', cb) callback, data= " + JSON.stringify(data));
    });

    sockjs.on('new-move', function(data) {
        console.log("    inside sockjs.on('new-move', cb) callback, data= " + JSON.stringify(data));

        update_game(data.tiles, data.invalid_moves, data.header_html);
    });

    return sockjs;
}

function on_success(data, textStatus, jqXHR) {
    console.log('-- ajax post succeeded! -- textStatus: ' + textStatus);
}

function add_hidden_input(form_selector, name, value) {
        $('<input />').attr('type', 'hidden')
                      .attr('name', name)
                      .attr('value', value)
                      .appendTo(form_selector);
}

$(document).ready(function() {
    console.log('$(document).ready(function() { ... }) -- inside callback');
    ready();
});
