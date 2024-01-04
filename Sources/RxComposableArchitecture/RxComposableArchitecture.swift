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
            .cancellable(id: id, cancelInFlight: true)
            .asObservable()
    }

//    public static func cancel(id: AnyHashable) -> RxEffect {
//        return Effect<Element, Never>.cancel(id: id)
//            .asObservable()
//    }

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

extension RxEffect {
    /// Turns an effect into one that is capable of being canceled.
    ///
    /// To turn an effect into a cancellable one you must provide an identifier, which is used in
    /// `Effect.cancel(id:)` to identify which in-flight effect should be canceled. Any hashable
    /// value can be used for the identifier, such as a string, but you can add a bit of protection
    /// against typos by defining a new type that conforms to `Hashable`, such as an empty struct:
    ///
    ///     struct LoadUserId: Hashable {}
    ///
    ///     case .reloadButtonTapped:
    ///       // Start a new effect to load the user
    ///       return environment.loadUser
    ///         .map(Action.userResponse)
    ///         .cancellable(id: LoadUserId(), cancelInFlight: true)
    ///
    ///     case .cancelButtonTapped:
    ///       // Cancel any in-flight requests to load the user
    ///       return .cancel(id: LoadUserId())
    ///
    /// - Parameters:
    ///   - id: The effect's identifier.
    ///   - cancelInFlight: Determines if any in-flight effect with the same identifier should be
    ///     canceled before starting this new one.
    /// - Returns: A new effect that is capable of being canceled by an identifier.
    public func rxCancellable(id: AnyHashable, cancelInFlight: Bool = false) -> RxEffect {
        let effect = Observable.deferred { () -> Observable<Element> in
            cancellablesLock.lock()
            defer { cancellablesLock.unlock() }

            let subject = PublishSubject<Element>()
            var hasSubjectCompleted = false
            var values: [Element] = []
            var isCaching = true
            let disposable = self
                .do(onNext: { val in
                  guard isCaching else { return }
                  values.append(val)
                })
                .subscribe(subject)

            var cancellationDisposable: Disposable!
            var disposeKey: CompositeDisposable.DisposeKey?
            cancellationDisposable = Disposables.create {
                cancellablesLock.sync {
                    if !hasSubjectCompleted {
                        subject.onCompleted()
                    }
                    disposable.dispose()
                    guard let disposeKey = disposeKey else {
                        assertionFailure(
                        """
                        No disposeKey. Thid could occur when you're attempting to dispose of a cancellation disposable before it was stored.
                        """
                        )
                        return
                    }
                    cancellationDisposables[id]?.remove(for: disposeKey)
                    if cancellationDisposables[id]?.count == .some(0) {
                        cancellationDisposables[id] = nil
                    }
                }
            }

            if let compositeDispoable = cancellationDisposables[id] {
                disposeKey = compositeDispoable.insert(cancellationDisposable)
            } else {
                let compositeDisposable = CompositeDisposable()
                disposeKey = compositeDisposable.insert(cancellationDisposable)
                cancellationDisposables[id] = compositeDisposable
            }

            return Observable.from(values)
                .concat(subject)
                .do(
                    onError: { _ in
                        cancellationDisposable.dispose()
                    },
                    onCompleted: {
                        hasSubjectCompleted = true
                        cancellationDisposable.dispose()
                    },
                    onSubscribed: {
                        isCaching = false
                    },
                    onDispose: {
                        cancellationDisposable.dispose()
                    }
                )
        }

        return cancelInFlight ? .concat(.cancel(id: id), effect) : effect
    }

    /// An effect that will cancel any currently in-flight effect with the given identifier.
    ///
    /// - Parameter id: An effect identifier.
    /// - Returns: A new effect that will cancel any currently in-flight effect with the given
    ///   identifier.
    public static func cancel(id: AnyHashable) -> RxEffect {
        return .fireAndForget {
            cancellablesLock.sync {
                cancellationDisposables[id]?.dispose()
            }
        }
    }
}

var cancellationDisposables: [AnyHashable: CompositeDisposable] = [:]
let cancellablesLock = NSRecursiveLock()


extension NSRecursiveLock {
  @inlinable @discardableResult
  func sync<R>(work: () -> R) -> R {
    self.lock()
    defer { self.unlock() }
    return work()
  }
}
