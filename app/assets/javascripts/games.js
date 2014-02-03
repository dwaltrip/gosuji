console.log('Successfully loaded games.js')

var socket = null;
var modal = new Modal({ closeButton: false });

$(document).ready(function() {
    console.log('$(document).ready handler');

    // new move
    $('#board-table').on('click.new_move', '.tile-container.clickable', function() {
        disable_turn_actions();
        ajax_post_helper(this, { new_move: $(this).data('board-pos') }, update_game);
    });

    // pass turn
    $('#pass-turn-form').on('submit.pass_turn', function(e) {
        e.preventDefault();
        disable_turn_actions();
        ajax_post_helper(this, null, update_game);
    });

    // undo request approval/rejection
    $(modal.selector).on('click.undo_approval', '#undo-approval-form .button', function(e) {
        e.preventDefault();
        approval_status = $(this).attr('name');

        if (approval_status === "approved") disable_turn_actions();
        ajax_post_helper(this, { undo_status: approval_status }, update_game);

        modal.close();
    });

    socket = get_socket();
    socket.emit('subscribe-to-updates', { room_id: window.room_id });
});

function update_game(data) {
    console.log('-- update_game -- data:', data);

    $('#status-message').text(data.status_message);
    $('#black-capture-count').text(data.captures.black);
    $('#white-capture-count').text(data.captures.white);

    // for the now active player, re-enable turn actions (clickable tiles and pass button)
    if (data.active_player === true) {
        $('.tile-container.playable').addClass('clickable');
        $('#pass-button').prop('disabled', false);
    }
    if (hasKey(data, 'undo_button_disabled')) $('#undo-button').prop('disabled', data.undo_button_disabled);

    // update necessary tiles. no need to toggle any event listeners, thanks to event delegation
    for(var i = 0, len = data.tiles.length; i < len; i++) {
        var tile = data.tiles[i];
        var $tile = $('#tile-' + tile.pos);

        $tile.removeClass("empty black white playable clickable").addClass(tile.classes);
        if (hasKey(tile, 'image_src')) $tile.find('.tile-image').attr('src', tile.image_src);
    }
}

function disable_turn_actions() {
    $('div.tile-container.clickable').removeClass('clickable');
    $('#pass-button').prop('disabled', true);
}

function get_socket() {
    console.log('-- sockjs_url: ' + sockjs_url + '\n');
    var sockjs = new SockjsClient(sockjs_url);

    sockjs.on('connect', function() {
        console.log("sockjs successfully connected with protocol '" + sockjs.protocol + "'");
        sockjs.emit('successfully-connnected', { connection_id: connection_id });
    });

    sockjs.on('close', function() {
        console.log("sockjs connection close. callback args: " + JSON.stringify(Array.prototype.slice.call(arguments)));
    });

    sockjs.on('message', function(data) {
        console.log("inside sockjs.on('message', cb) callback, data= " + JSON.stringify(data));
    });

    sockjs.on('game-update', function(data) {
        console.log("inside sockjs.on('game-update', cb) callback, data= " + JSON.stringify(data));
        update_game(data);
        modal.close();
    });

    sockjs.on('undo-request', function(data) {
        console.log("inside sockjs.on('undo-request', cb) callback, data= " + JSON.stringify(data));
        if (!modal.currentlyDisplayed) modal.open({ content: data.approval_form });
    });

    return sockjs;
}

function ajax_post_helper(form_elem, extra_data, on_success_callback) {
    var $form = $(form_elem).closest('form');
    console.log('-- entering ajax_post -- form: ', $form.attr('id'));
    extra_data = extra_data || {};
    extra_data.connection_id = window.connection_id;

    for(var name in extra_data) {
        $('<input />', {
            type: 'hidden',
            name: name,
            value: extra_data[name],
            class: 'hidden-data'
        }).appendTo($form);
    }

    console.log('-- ajax_helper -- $.post for:', $form.attr('id'), '-- $form.serialize():', $form.serialize(), "\n");
    $.post($form.attr('action'), $form.serialize(), on_success_callback, 'json');

    // clear out hidden data, so future ajax actions have clean slate
    $('.hidden-data', $form).remove();
}

function hasKey(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
}

