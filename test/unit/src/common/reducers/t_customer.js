import expect from 'expect';

import { customer } from '../../../../../src/common/reducers/customer';
import * as ActionTypes from '../../../../../src/common/actions/customer';

describe('customer reducers', () => {

  it('should return the initial state', () => {
    expect(customer(undefined, {})).toEqual({
      errors: false,
      isFetching: false,
      success: false,
      token: false,
      tosAccepted: false
    });
  });

  it('should add token to state', () => {
    const state = {
      errors: false,
      isFetching: false,
      success: false,
      token: false,
      tosAccepted: 'date string'
    };
    const action = {
      type: ActionTypes.SEND_STRIPE_TOKEN,
      token: 'foo'
    };

    expect(customer(state, action)).toEqual({
      errors: false,
      isFetching: true,
      success: false,
      token: 'foo',
      tosAccepted: 'date string'
    });
  });

  it('should handle success', () => {
    const action = {
      type: ActionTypes.SEND_STRIPE_TOKEN_SUCCESS,
      tosAccepted: 'datetime'
    };

    expect(customer({}, action)).toEqual({
      isFetching: false,
      success: true,
      tosAccepted: 'datetime'
    });
  });

  it('should handle failure', () => {
    const action = {
      type: ActionTypes.SEND_STRIPE_TOKEN_FAILURE,
      errors: []
    };

    expect(customer({}, action)).toEqual({
      isFetching: false,
      success: false,
      errors: []
    });
  });
});
