console.log('Successfully loaded games.js')

var socket = null;
var modal = new Modal({ closeButton: false });

var ready = function() {
    add_move_handler();

    $('#game-action-form').on('submit.game_action', function(e) {
        e.preventDefault();
        console.log("Inside #game-action-form on 'submit' callback");

        turn_off_game_actions();

        var move_id = 'game-' + game_id + '-move-' + move_num;
        add_hidden_input('#game-action-form', 'hidden-turn-data', 'move_id', move_id);
        socket.emit('submitted-game-action', { move_id: move_id, from: 'websocket' });

        console.log('--- form serialize --- ' + $('#game-action-form').serialize());
        return true;
    });

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
        add_hidden_input('#game-action-form', 'hidden-turn-data', 'new_move', tile_pos);
        add_hidden_input('#game-action-form', 'hidden-turn-data', 'move_id', move_id);

        console.log('submitting form via jquery/ajax');

        turn_off_game_actions();

        console.log('--- form serialize --- ' + $('#game-action-form').serialize());
        $.post($('#game-action-form').attr('action'), $('#game-action-form').serialize(), on_success, 'script');
        socket.emit('submitted-game-action', { move_id: move_id, from: 'websocket' });
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
    enable_game_action_buttons();
    $('.hidden-turn-data').remove();
}

function turn_off_game_actions() {
    $('div.tile_container.clickable').removeClass('clickable');
    $('div.tile_container').off('click.new_move');

    $('#game-action-form .button').prop('disabled', true);
}

function enable_game_action_buttons() {
    $('#game-action-form .button').prop('disabled', false);
}

function get_socket() {
    console.log('-- sockjs_url: ' + sockjs_url + '\n');

    var sockjs = new SockjsClient(sockjs_url, { verbose: true });

    sockjs.on('connect', function() {
        console.log("sockjs successfully connected with protocol '" + sockjs.protocol + "'");
        sockjs.emit('successfully-connnected', { info: 'hello server, client has connected' });
    });

    sockjs.on('close', function() {
        console.log("sockjs connection close. callback args: " + JSON.stringify(Array.prototype.slice.call(arguments)));
    });

    sockjs.on('message', function(data) {
        console.log("inside sockjs.on('message', cb) callback, data= " + JSON.stringify(data));
    });

    sockjs.on('game-update', function(data) {
        console.log("inside sockjs.on('game-update', cb) callback, data= " + JSON.stringify(data));

        update_game(data.tiles, data.invalid_moves, data.header_html);
        if (data.disable_undo_button) $('#undo-button').prop('disabled', true);
        sockjs.emit('received-game-update', { event_id: data.event_id });
    });

    sockjs.on('undo-request', function(data) {
        console.log("inside sockjs.on('undo-request', cb) callback, data= " + JSON.stringify(data));
        socket.emit('received-undo-request', { request_id: data.event_id });

        if (!modal.currentlyDisplayed) {
            modal.open({ content: data.undo_approval_form });

            $(modal.contentId + " #yes-button").on('click.undo-approval', function(e) {
                e.preventDefault();
                submit_undo_request('approved');
            });
            $(modal.contentId + " #no-button").on('click.undo-approval', function(e) {
                e.preventDefault();
                submit_undo_request('rejected');
            });
        }
    });

    return sockjs;
}

function submit_undo_request(approval_status) {
    console.log("submitting undo approval form -- approval_status: " + approval_status);
    $('#undo-status').val(approval_status);

    $.post($('#undo-approval-form').attr('action'), $('#undo-approval-form').serialize(), on_success, 'script');
    modal.close();
}

function on_success(data, textStatus, jqXHR) {
    console.log('-- ajax post succeeded! -- textStatus: ' + textStatus);
}

function add_hidden_input(form_selector, cls, name, value) {
        $('<input />', {
            type: 'hidden',
            name: name,
            value: value,
            class: cls
        }).appendTo(form_selector);
}

$(document).ready(function() {
    console.log('$(document).ready(function() { ... }) -- inside callback');
    ready();
});
