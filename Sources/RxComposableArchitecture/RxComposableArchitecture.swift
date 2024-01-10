// The Swift Programming Language
// https://docs.swift.org/swift-book

import ComposableArchitecture
import Combine
import Foundation
import RxCombine
import RxSwift

public typealias RxEffect<T> = RxSwift.Observable<T>

extension Reducer {
    public init(_ rxReducer: @escaping (inout State, Action, Environment) -> RxEffect<Action>) {
        self.init { state, action, env in
            return rxReducer(&state, action, env)
                .publisher
                .catch { error in Empty<Action, Never>() }
                .eraseToEffect()
        }
    }
}

extension RxEffect {
    public static func timeout<Action>(
        id: AnyHashable,
        cancelInFlight: Bool = false,
        dueTime: RxTimeInterval,
        action: Action,
        scheduler: SchedulerType
    ) -> RxEffect<Action> {
        RxEffect<Int>.timer(dueTime, scheduler: scheduler)
            .map { _ in action }
            .publisher
            .eraseToEffect()
            .cancellable(id: id, cancelInFlight: cancelInFlight)
            .asObservable()
    }

    public static func cancel(id: AnyHashable) -> RxEffect {
        return Effect<Element, Never>.cancel(id: id)
            .asObservable()
    }

    public func cancellable(id: AnyHashable, cancelInFlight: Bool = false) -> RxEffect {
        self.publisher.eraseToEffect().cancellable(id: id, cancelInFlight: cancelInFlight).asObservable()
    }

    public static func fireAndForget(_ work: @escaping () -> Void) -> RxEffect {
        return Effect<Element, Never>.fireAndForget {
            work()
        }
        .asObservable()
    }

    public func fireAndForget<NewOutput>() -> RxEffect<NewOutput> {
        self
            .flatMap { _ in RxEffect<NewOutput>.empty() }
            .catch { _ in .empty() }
    }

    public static func effect<T>(from rxEffect: RxEffect<T>) -> Effect<T, Error> {
        Effect(rxEffect.publisher.eraseToEffect())
    }
}

extension ViewStore {
    public var observable: StoreObservable<State> {
        StoreObservable(self.publisher.asObservable())
    }
}

@dynamicMemberLookup
public struct StoreObservable<State>: InfallibleType {
    public func asObservable() -> Observable<State> {
        self.upstream
    }

    public init(_ upstream: Observable<State>) {
        self.upstream = upstream
    }

    public typealias Element = State
    public let upstream: Observable<State>

    public func subscribe<Observer: ObserverType>(_ observer: Observer) -> Disposable where Observer.Element == Element {
        upstream.subscribe(observer)
    }

    public subscript<LocalState: Equatable>(
        dynamicMember keyPath: KeyPath<State, LocalState>
    ) -> StoreObservable<LocalState> {
        .init(self.upstream.map { $0[keyPath: keyPath] } .distinctUntilChanged())
    }
}
